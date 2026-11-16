import {expect,it,vi} from 'vitest';
import {runGemini, withinAssistantDeadline, type AssistantMetrics} from '../src/modules/chatbot/chatbot-service';
import {validBookingToolArgs, mapAssistantCandidates} from '../src/modules/chatbot/assistant-booking-tools';

it('only permits fixed 60-minute new coaching suggestions',()=>{
 expect(validBookingToolArgs('get_coaching_options',{coachId:'coach',durationMinutes:30})).toBe(false);
 expect(validBookingToolArgs('get_coaching_options',{coachId:'coach',durationMinutes:60})).toBe(true);
});
it('bounds hung tool/provider work by a remaining deadline',async()=>{
 await expect(withinAssistantDeadline(new Promise(()=>{}),5)).rejects.toMatchObject({code:'deadline-exceeded'});
});
it('reads candidate pages at bounded concurrency without changing directory order',async()=>{
 let active=0,peak=0;
 const result=await mapAssistantCandidates([1,2,3,4,5,6],async value=>{
  active++;peak=Math.max(peak,active);await new Promise(resolve=>setTimeout(resolve,1));active--;return value*2;
 });
 expect(result).toEqual([2,4,6,8,10,12]);expect(peak).toBeGreaterThan(1);expect(peak).toBeLessThanOrEqual(4);
});
it('rejects oversized provider bodies before parsing generated content',async()=>{
 const response=new Response('x'.repeat(131073));
 await expect(runGemini('fixture','Explain warmup',[],async()=>({}),vi.fn().mockResolvedValue(response))).rejects.toMatchObject({code:'resource-exhausted'});
});
it('distinguishes provider timeouts and unavailable configuration without exposing raw details',async()=>{
 await expect(runGemini('fixture','Warmup',[],async()=>({}),vi.fn().mockRejectedValue(Object.assign(new Error('private transport detail'),{name:'AbortError'})))).rejects.toMatchObject({code:'deadline-exceeded'});
 await expect(runGemini('','Warmup',[],async()=>({}),vi.fn())).rejects.toMatchObject({code:'failed-precondition',details:{reason:'provider-configuration'}});
});
it('returns trusted terminal tool facts without paying for a discarded continuation',async()=>{
 const metrics:AssistantMetrics={providerRequests:0,toolCalls:0,inputTokens:0,outputTokens:0,thinkingTokens:0,usageComplete:true};
 const fetcher=vi.fn().mockResolvedValue({ok:true,json:async()=>({modelVersion:'fixture-model',usageMetadata:{promptTokenCount:120,candidatesTokenCount:20,thoughtsTokenCount:3},candidates:[{content:{parts:[{functionCall:{name:'list_coaches',args:{}}}]}}]})});
 const result=await runGemini('fixture','Find a coach',[],async()=>({bookingCreated:false}),fetcher,undefined,{metrics,terminalReply:()=> 'Trusted current Coaches'});
 expect(result).toBe('Trusted current Coaches');expect(fetcher).toHaveBeenCalledOnce();
 expect(metrics).toMatchObject({providerRequests:1,toolCalls:1,inputTokens:120,outputTokens:20,thinkingTokens:3,usageComplete:true,model:'fixture-model'});
 expect(JSON.stringify(metrics)).not.toContain('Find a coach');
});
