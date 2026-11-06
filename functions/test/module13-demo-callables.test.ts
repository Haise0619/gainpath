import {describe,it,expect} from 'vitest';
import {parseModule13DemoEnvelope,MODULE13_DEMO_CALLABLE_OPTIONS,MODULE13_DEMO_DEPLOYMENT_ALLOWLIST,module13DemoAdminCommand,module13DemoMemberCommand} from '../src/modules/recommendation/demo-callables';
import {requireSyntheticQueue} from '../src/modules/recommendation/recommendation-queue-security';
import {MemoryStore} from './memory-store';
describe('reviewed demo callable transport',()=>{
 it('uses strict bounded grouped operations with real wrapper enforcement metadata',()=>{
  expect(parseModule13DemoEnvelope({schemaVersion:1,operation:'admin.queue.list',data:{organizationId:'gainpath'}},'admin').operation).toBe('admin.queue.list');
  expect(()=>parseModule13DemoEnvelope({schemaVersion:1,operation:'admin.queue.list',data:{organizationId:'gainpath'}},'member')).toThrow();
  expect(()=>parseModule13DemoEnvelope({schemaVersion:1,operation:'member.inbox',data:{organizationId:'gainpath',demoMode:true}},'member')).toThrow();
  expect(()=>parseModule13DemoEnvelope({schemaVersion:1,operation:'session.access',data:{organizationId:'gainpath'}},'delivery')).toThrow();
  expect(()=>parseModule13DemoEnvelope({schemaVersion:1,operation:'member.inbox',data:{organizationId:'gainpath',padding:'x'.repeat(17000)}},'member')).toThrow();
  expect(MODULE13_DEMO_CALLABLE_OPTIONS.enforceAppCheck).toBe(true);expect(MODULE13_DEMO_CALLABLE_OPTIONS.region).toBe('asia-southeast1');
  expect(MODULE13_DEMO_DEPLOYMENT_ALLOWLIST).toHaveLength(3);
  expect(module13DemoAdminCommand.__endpoint.callableTrigger).toBeDefined();
  expect(module13DemoMemberCommand.__endpoint.callableTrigger).toBeDefined();
 });
 it('a serialized capability or client flags cannot activate the existing queue services',()=>{
  expect(()=>requireSyntheticQueue({store:new MemoryStore(),readAuthIdentity:async()=>{throw Error('not called');},demoCapability:{}},'gainpath')).toThrow();
 });
});
