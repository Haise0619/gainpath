import type { DocumentStore } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { currentBookingMembership, requireBookingOrganization, bookingCoachScope, coachEligibilityFailure, currentBookingPolicy } from '../coaching/booking-validation';
import {localDate,dateEpoch} from '../coaching/coach-availability-contracts';
import { getMemberBookingOptionsService } from '../coaching/member-booking-options-service';
import { getBookingPaymentQuote } from '../commerce/booking-payment-service';
import type { CoachIdentityReader } from '../coaching/coach-profile-service';

const id=(v:unknown)=>typeof v==='string'&&/^[\w-]{1,128}$/.test(v);
/** Request-local bounded work; preserves the canonical directory order. */
export async function mapAssistantCandidates<T,R>(values:readonly T[],read:(value:T)=>Promise<R>):Promise<R[]> {
 const results:R[]=[];
 for(let i=0;i<values.length;i+=4)results.push(...await Promise.all(values.slice(i,i+4).map(read)));
 return results;
}
export function validBookingToolArgs(name:string,raw:unknown):raw is Record<string,unknown>{
 if(!raw||typeof raw!=='object'||Array.isArray(raw))return false;
 const a=raw as Record<string,unknown>;
 if(name==='list_coaches')return Object.keys(a).every(k=>k==='afterCoachId')&&(a.afterCoachId===undefined||id(a.afterCoachId));
 if(!['get_coaching_options','propose_booking'].includes(name))return false;
 const proposal=name==='propose_booking';
 if(Object.keys(a).some(k=>!['coachId','localDate','durationMinutes',...(proposal?['branchId','startAtMillis']:[])].includes(k)))return false;
 return id(a.coachId)&&a.durationMinutes===60
   &&(a.localDate===undefined?!proposal:typeof a.localDate==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(a.localDate))
   &&(!proposal||id(a.branchId)&&Number.isSafeInteger(a.startAtMillis)&&Number(a.startAtMillis)>0&&Number(a.startAtMillis)%1800000===0);
}
export interface AssistantBookingSuggestion {
 schemaVersion:1;coachId:string;coachName:string;branchId:string;branchName:string;localDate:string;timeZone:string;
 startAtMillis:number;endAtMillis:number;startLabel:string;endLabel:string;durationMinutes:30|60;amountMinor:number;currency:'MYR';
 expiresAtMillis:number;requiresConfirmation:true;
}
export interface AssistantCoachAvailability {
 schemaVersion:1;localDate:string;timeZone:string;durationMinutes:60;expiresAtMillis:number;truncated:boolean;nextAfterCoachId?:string;
 items:{coachId:string;name:string;branchId:string;branchName:string;startAtMillis:number;endAtMillis:number;startLabel:string;endLabel:string;amountMinor:number;currency:'MYR'}[];
}
export class AssistantBookingTools {
 availabilityToolCalls=0;
 suggestion?:AssistantBookingSuggestion;
  context?:{coachId:string;localDate:string;durationMinutes:30|60;expiresAtMillis:number};
 constructor(private store:DocumentStore,private auth:{uid:string;token:Record<string,unknown>}|undefined,private org:string,
   private listIds:(after?:string)=>Promise<string[]>,private identity:CoachIdentityReader,private clock=Date.now){}
 private async scope(){
   requireVerifiedEmail(this.auth);
   return this.store.transact(async tx=>{
     const m=await currentBookingMembership(tx,this.org,this.auth!.uid);await requireBookingOrganization(tx,this.org);
     if(m.role!=='member')throw new DomainError('permission-denied','Current Member access is required.');return m;
   });
 }
 /** Explicit date intent is resolved without an AI-generated date or slot.
  * All candidates on this bounded directory page are checked; never call an
  * eligible directory entry "available" before the existing slot service. */
 async availableCoaches(request:{dayOffset?:0|1;localDate?:string}):Promise<AssistantCoachAvailability>{
   await this.scope();
   const policy=await this.store.transact(async tx=>{
     await currentBookingMembership(tx,this.org,this.auth!.uid);await requireBookingOrganization(tx,this.org);
     return currentBookingPolicy(await tx.get(`orgs/${this.org}/settings/booking`));
   });
   const now=this.clock(),today=localDate(now,policy.timeZone);
   const day=request.localDate??new Date(dateEpoch(today)+(request.dayOffset??0)*86400000).toISOString().slice(0,10);
   dateEpoch(day);
   this.availabilityToolCalls=1;
   const directory=await this.execute('list_coaches',{}) as {items:{coachId:string}[];nextAfterCoachId?:string};
   const pages=await mapAssistantCandidates(directory.items,async coach=>{
     this.availabilityToolCalls++;
     const value=await this.execute('get_coaching_options',{coachId:coach.coachId,localDate:day,durationMinutes:60}) as {items:({coachName:string;branchName:string;branchId:string;startAtMillis:number;endAtMillis:number;startLabel:string;endLabel:string;amountMinor:number;currency:'MYR'})[]};
     return value.items.map(slot=>({coachId:coach.coachId,name:slot.coachName,branchId:slot.branchId,branchName:slot.branchName,startAtMillis:slot.startAtMillis,endAtMillis:slot.endAtMillis,startLabel:slot.startLabel,endLabel:slot.endLabel,amountMinor:slot.amountMinor,currency:slot.currency}));
   });
   this.context=undefined;
   await this.scope();
   const selected=pages.flatMap(slots=>slots.slice(0,3)).slice(0,20);
   return{schemaVersion:1,localDate:day,timeZone:policy.timeZone,durationMinutes:60,
     expiresAtMillis:Math.min(now+300000,...selected.map(slot=>slot.startAtMillis)),items:selected,
     truncated:!!directory.nextAfterCoachId||pages.reduce((sum,slots)=>sum+slots.length,0)>selected.length,
     ...(directory.nextAfterCoachId?{nextAfterCoachId:directory.nextAfterCoachId}:{})};
 }
 async execute(name:string,args:Record<string,unknown>):Promise<unknown>{
   if(!validBookingToolArgs(name,args))throw new DomainError('invalid-argument','Invalid booking read tool.');
   await this.scope();
   if(name==='list_coaches'){
     const ids=await this.listIds(args.afterCoachId as string|undefined);
     if(ids.length>21||ids.some(v=>!id(v))||new Set(ids).size!==ids.length)throw new DomainError('failed-precondition','Coach directory needs review.');
     const candidates=await mapAssistantCandidates(ids.slice(0,20),async coachId=>{
       try{
         const failure=await coachEligibilityFailure(this.identity,coachId);if(failure)throw failure;
         const branches=await this.store.transact(async tx=>{const m=await currentBookingMembership(tx,this.org,this.auth!.uid);return (await bookingCoachScope(tx,this.org,coachId,m.branchIds)).permitted;});
         const quote=await getBookingPaymentQuote(this.store,this.auth,{schemaVersion:1,organizationId:this.org,coachId,branchId:branches[0],durationMinutes:60});
         return {coachId,name:quote.coachName,branchId:branches[0],branchName:quote.branchName,amountMinor:quote.amountMinor,currency:quote.currency};
       }catch(e){if(!(e instanceof DomainError)||!['permission-denied','failed-precondition','not-found'].includes(e.code))throw e;}
     });
     const items=candidates.filter((value):value is NonNullable<typeof value>=>value!==undefined);
     await this.scope();
     return {items,...(ids.length>20?{nextAfterCoachId:ids[19]}:{}),bookingCreated:false};
   }
   const options=await getMemberBookingOptionsService(this.store,this.auth,{schemaVersion:1,organizationId:this.org,coachId:args.coachId,durationMinutes:args.durationMinutes,...(args.localDate===undefined?{}:{localDate:args.localDate})},this.identity,this.clock);
   this.context={coachId:options.coachId,localDate:options.localDate,durationMinutes:options.durationMinutes,expiresAtMillis:this.clock()+300000};
   if(name==='get_coaching_options'){
     const items=[];
     const quotes=new Map<string,Awaited<ReturnType<typeof getBookingPaymentQuote>>>();
     for(const slot of options.options){
       if(!quotes.has(slot.branchId))quotes.set(slot.branchId,await getBookingPaymentQuote(this.store,this.auth,{schemaVersion:1,organizationId:this.org,coachId:args.coachId,branchId:slot.branchId,durationMinutes:args.durationMinutes}));
       const quote=quotes.get(slot.branchId)!;items.push({...slot,coachName:quote.coachName,branchName:quote.branchName,amountMinor:quote.amountMinor,currency:quote.currency});
     }
     await this.scope();return {coachId:options.coachId,localDate:options.localDate,timeZone:options.timeZone,todayLocalDate:options.todayLocalDate,throughLocalDate:options.throughLocalDate,durationMinutes:options.durationMinutes,items,unavailableReason:options.unavailableReason,bookingCreated:false};
   }
   const slot=options.options.find(s=>s.branchId===args.branchId&&s.startAtMillis===args.startAtMillis);
   if(!slot)throw new DomainError('failed-precondition','Suggested time is unavailable. Read current options again.');
   const quote=await getBookingPaymentQuote(this.store,this.auth,{schemaVersion:1,organizationId:this.org,coachId:args.coachId,branchId:slot.branchId,durationMinutes:options.durationMinutes});
   await this.scope();
   this.suggestion={schemaVersion:1,coachId:options.coachId,coachName:quote.coachName,branchName:quote.branchName,localDate:options.localDate,timeZone:options.timeZone,...slot,durationMinutes:options.durationMinutes,amountMinor:quote.amountMinor,currency:'MYR',expiresAtMillis:Math.min(this.clock()+300000,slot.startAtMillis),requiresConfirmation:true};
   return {suggested:true,bookingCreated:false,requiresUserReview:true,coachName:quote.coachName,localDate:options.localDate,startLabel:slot.startLabel,endLabel:slot.endLabel,timeZone:options.timeZone,amountMinor:quote.amountMinor,currency:'MYR'};
 }
}
