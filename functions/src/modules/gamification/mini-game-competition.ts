import {createHash} from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {requireVerifiedEmail,requireActiveMembership} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {readAll,type DocumentStore,type DocumentData,type TransactionPort} from '../../platform/firestore/store';
import {requiredIdentifier} from '../../platform/validation';
type Auth={uid:string;token:Record<string,unknown>};
type Row={id:string;data:DocumentData};
interface Dependencies {clock?:()=>number;freshAuth(auth:Auth):Promise<void>;rows(gameId:string,after:string|undefined,limit:number):Promise<Row[]>}
const POLICY='game-competition-v1',GAMES=['move-catch-v1','reach-tap-v1'],TRUST='Gameplay results · not physically verified';
const hash=(...v:unknown[])=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
const integer=(v:unknown,min=0,max=8640000000000000):v is number=>Number.isSafeInteger(v)&&Number(v)>=min&&Number(v)<=max;
const hex=(v:unknown):v is string=>typeof v==='string'&&/^[a-f0-9]{32}$/.test(v);
const invalid=()=>new DomainError('invalid-argument','Invalid game competition command.');
const fail=()=>new DomainError('failed-precondition','A newly consented owned completed round is required.');
const deny=()=>new DomainError('permission-denied','Current scoped Member required.');
const changed=()=>new DomainError('aborted','Game standings changed. Refresh to retry.');
async function authorize(tx:TransactionPort,auth:Auth,org:string,allowAdmin=false){
 const[m,u,o]=await readAll(tx,[`orgs/${org}/members/${auth.uid}`,`users/${auth.uid}`,`orgs/${org}`]);
 const role=requireActiveMembership(m).role,l=u?.accountLifecycle as DocumentData|undefined;
 if(!(['member',...(allowAdmin?['admin']:[])].includes(role))||m?.organizationId!==org||(m.userId!==undefined&&m.userId!==auth.uid)||u?.organizationId!==org||(u.role!==undefined&&u.role!==role)||o?.status!=='active'||(l!==undefined&&(!l||l.schemaVersion!==1||l.state!=='active'||l.revocationPending!==false||!integer(l.sessionNotBeforeSeconds)||(l.sessionNotBeforeSeconds>0&&(!integer(auth.token.auth_time)||auth.token.auth_time<l.sessionNotBeforeSeconds)))))throw deny();
}
function preference(d:DocumentData|undefined,org:string,uid:string){
 if(!d)return {schemaVersion:1,organizationId:org,memberId:uid,enabled:false,policyVersion:POLICY,revision:0,changedAtMillis:0};
 if(d.schemaVersion!==1||d.organizationId!==org||d.memberId!==uid||d.policyVersion!==POLICY||typeof d.enabled!=='boolean'||!integer(d.revision,1)||!integer(d.changedAtMillis,1))throw fail();
 return d as {schemaVersion:number;organizationId:string;memberId:string;enabled:boolean;policyVersion:string;revision:number;changedAtMillis:number};
}
export function competitionWeek(now:number){const day=86400000,offset=8*3600000,ordinal=Math.floor((now+offset)/day),weekday=new Date(ordinal*day).getUTCDay();return String((ordinal-(weekday+6)%7)*day-offset);}
function parse(raw:unknown){if(!raw||typeof raw!=='object'||Array.isArray(raw))throw invalid();const d=raw as DocumentData;
 const actions:Record<string,string[]>={preference:[],setPreference:['enabled','policyVersion'],leaderboard:['gameId','period'],submit:['gameId','scoringVersion','attemptId','challengeToken','events']};
 if(d.schemaVersion!==1||typeof d.action!=='string'||!Object.hasOwn(actions,d.action))throw invalid();const keys=['schemaVersion','organizationId','action',...actions[d.action]];
 if(Object.keys(d).length!==keys.length||Object.keys(d).some(k=>!keys.includes(k)))throw invalid();requiredIdentifier(d.organizationId,'organizationId');
 if(d.action==='setPreference'&&(typeof d.enabled!=='boolean'||d.policyVersion!==POLICY))throw invalid();
 if(['submit','leaderboard'].includes(d.action)&&!GAMES.includes(String(d.gameId)))throw invalid();
 if(d.action==='leaderboard'&&!['week','all-time'].includes(String(d.period)))throw invalid();
 if(d.action==='submit'&&(d.scoringVersion!==1||!hex(d.attemptId)||!hex(d.challengeToken)||!Array.isArray(d.events)||d.events.length>400))throw invalid();return d;
}
function score(game:string,events:unknown[]){if(game==='move-catch-v1'&&events.length>57)throw invalid();let result=0,last=-1000;for(let i=0;i<events.length;i++){const e=events[i] as DocumentData;
 if(!e||typeof e!=='object'||Array.isArray(e)||Object.keys(e).sort().join(',')!=='activeMillis,sequence,type'||e.sequence!==i+1||!integer(e.activeMillis,0,40000)||e.activeMillis-last<(game==='reach-tap-v1'?100:0)||!(game==='reach-tap-v1'?['hit']:['catch','obstacle']).includes(String(e.type)))throw invalid();
 if(game==='move-catch-v1'&&i>=6&&e.activeMillis-Number((events[i-6] as DocumentData).activeMillis)<1000)throw invalid();
 last=e.activeMillis;result=Math.max(0,result+(e.type==='obstacle'?-5:10));}return result;}
function alias(m:DocumentData,u:DocumentData|undefined){const raw=typeof m.displayName==='string'?m.displayName:u?.displayName;if(typeof raw!=='string'||raw.includes('@'))return 'Member';return raw.replace(/[\u0000-\u001f\u007f]/g,'').replace(/\s+/g,' ').trim().slice(0,60)||'Member';}
/** Competitive projections only: never writes wallet, participation claims or physical verification. */
export async function miniGameCompetition(store:DocumentStore,auth:Auth|undefined,raw:unknown,deps:Dependencies){requireVerifiedEmail(auth);const d=parse(raw),org=String(d.organizationId),uid=requiredIdentifier(auth!.uid,'uid'),now=(deps.clock??Date.now)();if(!integer(now,1,8640000000000000-86400000))throw invalid();await deps.freshAuth(auth!);
 const base=`orgs/${org}`,prefPath=(member:string)=>`${base}/miniGameCompetitionPreferences/${member}`,bestPath=(member:string,game:string)=>`${base}/miniGameScoreBests/${hash(member)}_${game}`;
 if(d.action==='leaderboard'){
  await store.transact(tx=>authorize(tx,auth!,org,true));const game=String(d.gameId),period=String(d.period),week=competitionWeek(now);const rows:Row[]=[];
  const scan=async()=>{const rows:Row[]=[];let after:string|undefined;while(true){const next=await deps.rows(game,after,100);if(next.length>100)throw changed();let previous=after;for(const row of next){if(!/^[a-f0-9]{64}_(move-catch-v1|reach-tap-v1)$/.test(row.id)||(previous!==undefined&&row.id<=previous))throw changed();previous=row.id;}rows.push(...next);if(rows.length>500)throw new DomainError('resource-exhausted','Game standings exceed the demo scan range.');if(next.length<100)break;after=next.at(-1)!.id;}return rows;};
  rows.push(...await scan());
  const ranked=await store.transact(async tx=>{await authorize(tx,auth!,org,true);const current=await readAll(tx,rows.flatMap(row=>[`${base}/miniGameScoreBests/${row.id}`,prefPath(String(row.data.memberId)),`${base}/members/${String(row.data.memberId)}`,`users/${String(row.data.memberId)}`]));const accepted:{uid:string;displayName:string;score:number}[]=[];
   for(let i=0;i<rows.length;i++){const [best,p,m,u]=current.slice(i*4,i*4+4);if(!isDeepStrictEqual(best,rows[i].data))throw changed();if(!best||best.schemaVersion!==1||best.organizationId!==org||best.gameId!==game||best.scoringVersion!==1||typeof best.memberId!=='string'||rows[i].id!==`${hash(best.memberId)}_${game}`)throw changed();
    const pref=preference(p,org,best.memberId);if(!pref.enabled||best.preferenceRevision!==pref.revision||best.visible!==true)continue;
    const lifecycle=u?.accountLifecycle as DocumentData|undefined;if(!m||m.status!=='active'||m.role!=='member'||m.organizationId!==org||(m.userId!==undefined&&m.userId!==best.memberId)||u?.organizationId!==org||(u.role!==undefined&&u.role!=='member')||(lifecycle!==undefined&&(!lifecycle||lifecycle.state!=='active'||lifecycle.revocationPending!==false)))continue;
    const value=period==='week'?(best.weekKey===week?best.weekScore:null):best.allTimeScore;if(value===null||value===undefined)continue;if(!integer(value,0,4000))throw changed();accepted.push({uid:best.memberId,displayName:alias(m,u),score:value});}
   accepted.sort((a,b)=>b.score-a.score||a.uid.localeCompare(b.uid));let rank=0;return accepted.map((r,i)=>{if(i===0||r.score!==accepted[i-1].score)rank=i+1;return {rank,displayName:r.uid===uid?'You':r.displayName,score:r.score,isYou:r.uid===uid};});});
  if(!isDeepStrictEqual(rows,await scan()))throw changed();await deps.freshAuth(auth!);await store.transact(tx=>authorize(tx,auth!,org,true));return {schemaVersion:1,organizationId:org,memberId:uid,gameId:game,period,periodKey:period==='week'?week:'all-time',scoringVersion:1,entries:ranked.slice(0,20),you:ranked.find(r=>r.isYou)??{rank:null,displayName:'You',score:null,isYou:true},totalParticipants:ranked.length,resolvedAtMillis:now,trustLabel:TRUST};
 }
 const result=await store.transact(async tx=>{await authorize(tx,auth!,org);const pref=preference(await tx.get(prefPath(uid)),org,uid);
  if(d.action==='preference')return pref;
  if(d.action==='setPreference'){
   if(pref.enabled===d.enabled&&pref.revision>0)return pref;
   const bests=await readAll(tx,GAMES.map(g=>bestPath(uid,g)));const updated={...pref,enabled:d.enabled as boolean,revision:pref.revision+1,changedAtMillis:now};tx.set(prefPath(uid),updated);
   GAMES.forEach((g,i)=>{if(bests[i])tx.set(bestPath(uid,g),{...bests[i],visible:false,preferenceRevision:updated.revision,weekScore:null,allTimeScore:null,weekKey:competitionWeek(now)});});return updated;
  }
  const game=String(d.gameId),computed=score(game,d.events as unknown[]),fingerprint=hash(game,1,(d.events as DocumentData[]).map(e=>({sequence:e.sequence,activeMillis:e.activeMillis,type:e.type}))),receiptPath=`${base}/miniGameScoreReceipts/${String(d.attemptId)}`;
  const [round,prior,best]=await readAll(tx,[`${base}/miniGameRoundSessions/${String(d.attemptId)}`,receiptPath,bestPath(uid,game)]);
  if(!round||round.memberId!==uid||round.organizationId!==org||round.attemptId!==d.attemptId||round.gameId!==game||round.challengeToken!==d.challengeToken)throw deny();
  if(prior){if(prior.memberId!==uid||prior.organizationId!==org||prior.fingerprint!==fingerprint)throw new DomainError('already-exists','Score submission already used with different events.');const r=prior.result as DocumentData|undefined;if(!r||r.schemaVersion!==1||r.organizationId!==org||r.memberId!==uid||r.gameId!==game||r.attemptId!==d.attemptId||r.score!==computed||!integer(r.acceptedAtMillis,1,now)||r.physicalVerified!==false||r.pointsAwarded!==0)throw fail();return {schemaVersion:1,organizationId:org,memberId:uid,gameId:game,attemptId:d.attemptId,score:computed,acceptedAtMillis:r.acceptedAtMillis,physicalVerified:false,pointsAwarded:0};}
  if(!pref.enabled||!integer(round.startedAtMillis,1)||round.startedAtMillis<=pref.changedAtMillis||round.status!=='awaiting_verification'||round.activeMillis!==40000||!integer(round.lastAtMillis,round.startedAtMillis+40000,now)||round.physicalVerified!==false||round.pointsAwarded!==0)throw fail();
  if(best&&(best.schemaVersion!==1||best.organizationId!==org||best.memberId!==uid||best.gameId!==game||best.scoringVersion!==1||typeof best.visible!=='boolean'||!integer(best.preferenceRevision,1)||(best.weekScore!==null&&!integer(best.weekScore,0,4000))||(best.allTimeScore!==null&&!integer(best.allTimeScore,0,4000))))throw fail();
  const same=best?.visible===true&&best.preferenceRevision===pref.revision,completedWeek=competitionWeek(Number(round.lastAtMillis)),week=same&&Number(best?.weekKey)>Number(completedWeek)?String(best?.weekKey):completedWeek;
  const weekScore=week!==completedWeek?Number(best?.weekScore??0):Math.max(computed,same&&best?.weekKey===week?Number(best.weekScore??0):0);
  const result={schemaVersion:1,organizationId:org,memberId:uid,gameId:game,attemptId:d.attemptId,score:computed,acceptedAtMillis:now,physicalVerified:false,pointsAwarded:0};
  tx.create(receiptPath,{schemaVersion:1,organizationId:org,memberId:uid,fingerprint,result,preferenceRevision:pref.revision});
  tx.set(bestPath(uid,game),{schemaVersion:1,organizationId:org,memberId:uid,gameId:game,scoringVersion:1,visible:true,preferenceRevision:pref.revision,weekKey:week,weekScore,allTimeScore:Math.max(computed,same?Number(best?.allTimeScore??0):0)});return result;
 });await deps.freshAuth(auth!);await store.transact(tx=>authorize(tx,auth!,org));return result;
}

/** Namespaced extension of the existing round callable; no separate Firebase service. */
export async function miniGameCompetitionEnvelope(store:DocumentStore,auth:Auth|undefined,raw:unknown,deps:Dependencies){
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw invalid();const d=raw as DocumentData;
 if(d.schemaVersion!==1||d.action!=='competition'||Object.keys(d).sort().join(',')!=='action,command,organizationId,schemaVersion'||!d.command||typeof d.command!=='object'||Array.isArray(d.command))throw invalid();
 const command=d.command as DocumentData;if(Object.hasOwn(command,'organizationId')||Object.hasOwn(command,'schemaVersion'))throw invalid();
 return miniGameCompetition(store,auth,{schemaVersion:1,organizationId:d.organizationId,...command},deps);
}
