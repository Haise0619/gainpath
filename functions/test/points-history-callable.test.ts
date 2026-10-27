import {beforeEach,expect,it,vi} from 'vitest';
const mocks=vi.hoisted(()=>({getUser:vi.fn(),transact:vi.fn(),collection:vi.fn()}));
vi.mock('firebase-admin/auth',()=>({getAuth:()=>({getUser:mocks.getUser})}));
vi.mock('firebase-admin/firestore',()=>({getFirestore:()=>({collection:mocks.collection}),FieldPath:{documentId:()=> '__name__'}}));
vi.mock('../src/platform/firestore/firestore-store',()=>({FirestoreStore:class{transact=mocks.transact;}}));
import {verifiedRewardsCommand} from '../src/modules/gamification/verified-rewards-callables';
import {miniGameParticipation} from '../src/modules/gamification/mini-game-participation';
import {auth as memberAuth,seed,now,org,path} from './reward-journey-fixture';
const auth={...memberAuth,token:{...memberAuth.token,email:'member@example.test'}};
let store:ReturnType<typeof seed>;
const request=(action='pointsHistoryAll')=>({app:{appId:'synthetic'},auth,data:{schemaVersion:1,organizationId:org,action}});
beforeEach(()=>{
 vi.resetAllMocks();vi.stubEnv('VERIFIED_REWARDS_ORGANIZATION_ID',org);
 vi.spyOn(Date,'now').mockReturnValue(now);
 store=seed();mocks.transact.mockImplementation(work=>store.transact(work));
 mocks.getUser.mockResolvedValue({disabled:false,emailVerified:true,email:auth.token.email,tokensValidAfterTime:new Date(0).toUTCString()});
 mocks.collection.mockImplementation((root:string)=>{
  const query:any={where:vi.fn((_field:string,_op:string,uid:string)=>{expect(uid).toBe(auth.uid);return query;}),orderBy:()=>query,limit:(n:number)=>{expect(n).toBe(201);return query;},
   get:async()=>({docs:[...store.documents.entries()].filter(([p,d])=>p.startsWith(root+'/')&&!p.slice(root.length+1).includes('/')&&d.memberId===auth.uid)
    .map(([p,data])=>({id:p.slice(root.length+1),data:()=>data}))})};
  return query;
 });
});
it('owned completed round to atomic credit to unified history uses the actual persisted receipt',async()=>{
 const attemptId='a'.repeat(32);
 store.documents.set(path('miniGameRoundSessions',attemptId),{schemaVersion:1,organizationId:org,memberId:auth.uid,gameId:'move-catch-v1',attemptId,status:'awaiting_verification',activeMillis:40000,sequence:21,startedAtMillis:now-45000,lastAtMillis:now-1000,expiresAtMillis:now-45000+900000,physicalVerified:false,pointsAwarded:0});
 await miniGameParticipation(store,auth,{...request().data,schemaVersion:2,action:'claimParticipation',attemptId},{clock:()=>now,freshAuth:async()=>{},releaseApproved:true});
 const response=await verifiedRewardsCommand.run(request() as any);
 expect(response).toMatchObject({schemaVersion:2,balance:1020,demoBalance:0,demoReconciled:true,entries:[expect.objectContaining({source:'mini_game_participation',points:20,wallet:'spendable'})]});
 expect(mocks.collection).toHaveBeenCalledTimes(5);
});
it('legacy installed clients retain the original history contract and four scans',async()=>{
 const response=await verifiedRewardsCommand.run(request('pointsHistory') as any);
 expect(response.schemaVersion).toBe(1);expect(response).not.toHaveProperty('demoBalance');
 expect(mocks.collection).toHaveBeenCalledTimes(4);
});
it('missing App Check and foreign organization are rejected before source scans',async()=>{
 await expect(verifiedRewardsCommand.run({...request(),app:undefined} as any)).rejects.toMatchObject({code:'unauthenticated'});
 await expect(verifiedRewardsCommand.run({...request(),data:{...request().data,organizationId:'foreign'}} as any)).rejects.toMatchObject({code:'permission-denied'});
 expect(mocks.collection).not.toHaveBeenCalled();
});
it('revoked identity after the history read never discloses the result',async()=>{
 mocks.getUser.mockResolvedValueOnce({disabled:false,emailVerified:true,email:auth.token.email,tokensValidAfterTime:new Date(0).toUTCString()})
  .mockResolvedValueOnce({disabled:true,emailVerified:true,email:auth.token.email});
 await expect(verifiedRewardsCommand.run(request() as any)).rejects.toMatchObject({code:'unauthenticated'});
});
