import { describe, expect, it, vi } from 'vitest';
import { createGeminiRecommendationRanker, RecommendationProviderError } from '../src/modules/recommendation/gemini-recommendation-ranker';
import { buildAnonymousRankingRequest } from '../src/modules/recommendation/recommendation-ai-validation';
import type { RankingCandidate } from '../src/modules/recommendation/recommendation-ranking-contracts';
const candidate: RankingCandidate = {id:'fictional',organizationId:'synthetic-org',kind:'content',eligibilityClass:'exact_exercise',specialtyFit:1,objectiveFit:1,levelFit:null,availabilityFit:null,experienceFit:null,evidence:[{key:'exercise',kind:'exercise_match',text:'Squat technique practice.',supports:['exercise_match']}]};
const request = () => buildAnonymousRankingRequest({exercise:'squat',objective:'technique_foundations',level:'beginner'},[candidate]).payload;
const ok = () => new Response(JSON.stringify({modelVersion:'gemini-3.5-flash-lite-001',candidates:[{finishReason:'STOP',content:{parts:[{text:'{"schemaVersion":1,"rankings":[]}'}]}}],usageMetadata:{promptTokenCount:120,candidatesTokenCount:30,thoughtsTokenCount:4,totalTokenCount:154}}));
describe('dedicated Gemini educational ranker REST boundary', () => {
  it('uses server key header, structured schema, no tools and bounded output', async () => {
    const fetcher = vi.fn(async (_url: any, init: any) => { const b=JSON.parse(init.body); expect(b.tools).toBeUndefined(); expect(b.generationConfig.responseMimeType).toBe('application/json'); expect(b.generationConfig.responseJsonSchema).toBeUndefined(); expect(b.generationConfig.responseSchema.type).toBe('OBJECT'); expect(b.generationConfig.responseSchema.properties.rankings.items.required).toContain('evidenceRefs'); expect(b.systemInstruction.parts[0].text).toContain('additionalProperties'); expect(b.generationConfig.maxOutputTokens).toBe(2048); expect(init.headers['x-goog-api-key']).toBe('synthetic-test-secret'); expect(init.body).not.toContain('fictional'); expect(init.signal).toBeInstanceOf(AbortSignal); return ok(); });
    const result = await createGeminiRecommendationRanker({apiKey:'synthetic-test-secret',model:'gemini-3.5-flash-lite',fetcher:fetcher as any})(request());
    expect(result.model).toBe('gemini-3.5-flash-lite-001'); expect(result.usage.totalTokens).toBe(154); expect(fetcher).toHaveBeenCalledTimes(1);
  });
  it.each([[429,'rate_limited'],[401,'authentication'],[403,'authentication'],[402,'billing_unavailable'],[503,'provider_unavailable']])('maps HTTP %s to safe %s without provider body',async (status,reason) => {
    const f=vi.fn(async()=>new Response('private error details',{status:Number(status)}));
    await expect(createGeminiRecommendationRanker({apiKey:'test',fetcher:f as any})(request())).rejects.toMatchObject({reason}); expect(f).toHaveBeenCalledTimes(1);
  });
  it('rejects oversize or incomplete envelopes', async () => {
    for(const body of [ 'x'.repeat(140000), JSON.stringify({candidates:[{finishReason:'MAX_TOKENS',content:{parts:[{text:'{}'}]}}]}), JSON.stringify({candidates:[{finishReason:'STOP',content:{parts:[{functionCall:{name:'book'}}]}}]}) ]) {
      await expect(createGeminiRecommendationRanker({apiKey:'test',fetcher:(async()=>new Response(body)) as any})(request())).rejects.toBeInstanceOf(RecommendationProviderError);
    }
  });
  it('aborts even when an injected transport ignores AbortSignal',async()=>{
    const provider=createGeminiRecommendationRanker({apiKey:'test',timeoutMillis:10,fetcher:(()=>new Promise(()=>{})) as any});
    await expect(provider(request())).rejects.toMatchObject({reason:'timeout'});
  });
  it('does not send unknown fields or malformed anonymous request to transport',async()=>{
    const f=vi.fn(async()=>ok()); const p=createGeminiRecommendationRanker({apiKey:'test',fetcher:f as any});
    await expect(p({...request(),memberId:'secret'} as any)).rejects.toMatchObject({reason:'invalid_request'}); expect(f).not.toHaveBeenCalled();
    await expect(p({...request(),kind:['content']} as any)).rejects.toMatchObject({reason:'invalid_request'});expect(f).not.toHaveBeenCalled();
  });
});
