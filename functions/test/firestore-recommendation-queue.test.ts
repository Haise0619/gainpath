import {expect,it} from 'vitest';
import {createFirestoreRecommendationQueueReader} from '../src/modules/recommendation/firestore-recommendation-queue';

it('is disabled without deliberate emulator composition before touching a supplied SDK',async()=>{
  let touched=false;
  const firestore={collection:()=>{touched=true;throw Error('unexpected');}} as any;
  const reader=createFirestoreRecommendationQueueReader({firestore});
  await expect(reader.readLeads('synthetic-org',null,10)).rejects.toMatchObject({code:'failed-precondition'});
  expect(touched).toBe(false);
});
it('fails closed for a substituted already initialized SDK transport',async()=>{
  const old=process.env.FIRESTORE_EMULATOR_HOST;process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:18111';
  try{
    for(const sdk of [
      {projectId:'gainpath',_settings:{servicePath:'127.0.0.1',port:18111,ssl:false}},
      {projectId:'demo-gainpath-module13-c',_settings:{servicePath:'firestore.googleapis.com',port:443,ssl:true}},
      {projectId:'demo-gainpath-module13-c',_settings:{servicePath:'127.0.0.1',port:18111,ssl:true}},
      {projectId:'demo-gainpath-module13-c'},
    ]){
      const reader=createFirestoreRecommendationQueueReader({firestore:sdk as any,localReview:{mode:'synthetic_emulator_only'}});
      await expect(reader.readLeads('synthetic-org',null,10)).rejects.toMatchObject({code:'failed-precondition'});
    }
  }finally{if(old===undefined)delete process.env.FIRESTORE_EMULATOR_HOST;else process.env.FIRESTORE_EMULATOR_HOST=old;}
});
