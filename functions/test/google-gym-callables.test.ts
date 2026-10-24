import {expect,it} from 'vitest';
import {googleGymConnectionCommand,googleGymOAuthCallback,syncGymBookingCommand,googleGymConnectionHandler} from '../src/modules/coaching/google-gym-callables';
import {MemoryStore} from './memory-store';
import {GymGoogleConnection} from '../src/modules/coaching/google-gym-connection';
it('requires the dedicated runtime parameter during deployment discovery without dotenv loaded',()=>{
 for(const f of [googleGymConnectionCommand,googleGymOAuthCallback,syncGymBookingCommand])expect(JSON.stringify(f.__endpoint.serviceAccountEmail)).toContain('GOOGLE_GYM_SERVICE_ACCOUNT');
});
it('binds only the OAuth secret and rejects absent App Check or authentication at the actual handler',async()=>{
 for(const f of [googleGymConnectionCommand,googleGymOAuthCallback,syncGymBookingCommand])expect(f.__endpoint.secretEnvironmentVariables).toContainEqual(expect.objectContaining({key:'GOOGLE_GYM_CLIENT_SECRET'}));
 await expect(googleGymConnectionHandler({data:{}} as any)).rejects.toMatchObject({code:'unauthenticated'});
 await expect(googleGymConnectionHandler({app:{},data:{}} as any)).rejects.toMatchObject({code:'unauthenticated'});
});
it('uses canonical role and organization on the callable status path',async()=>{
 const store=new MemoryStore();store.documents.set('users/coach',{organizationId:'org'});store.documents.set('orgs/org',{status:'active'});store.documents.set('orgs/org/members/coach',{organizationId:'org',role:'coach',status:'active',branchIds:[]});
 const connection=new GymGoogleConnection(store,{} as any,{} as any,{clientId:'',redirectUri:'',gymEmail:''});
 const deps={store,connection,provider:{} as any};const request={app:{appId:'app'},auth:{uid:'coach',token:{email_verified:true}},data:{organizationId:'org',action:'status',coachId:'coach'}} as any;
 expect(await googleGymConnectionHandler(request,deps)).toMatchObject({connectionStatus:'disconnected'});
 await expect(googleGymConnectionHandler({...request,data:{...request.data,coachId:'other'}},deps)).rejects.toMatchObject({code:'permission-denied'});
 await expect(googleGymConnectionHandler({...request,data:{...request.data,action:'connect'}},deps)).rejects.toBeDefined();
 await expect(googleGymConnectionHandler({...request,data:{...request.data,organizationId:'foreign'}},deps)).rejects.toMatchObject({code:'permission-denied'});
});
