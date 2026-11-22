import {describe, expect, it, vi} from 'vitest';
import {
  createGeminiWorkoutRecommendationRanker, rankWorkoutRecommendations,
  WORKOUT_RANKING_FACTORS,
  type WorkoutRankingCandidate, type WorkoutRankingContext, type WorkoutRankingFactor,
  type WorkoutRankingProvider,
} from '../src/modules/recommendation/workout-recommendation-ranking';

const candidate = (id: string, kind: WorkoutRankingCandidate<string>['kind'],
  factors: WorkoutRankingFactor[], detail: Partial<WorkoutRankingCandidate<string>> = {}): WorkoutRankingCandidate<string> =>
  ({kind, target: id, factors, ...detail});
const rank = (recommendationType: string, ranking: string[], relevantWorkoutFactors: string[]) =>
  ({recommendationType, ranking, relevantWorkoutFactors});
const inference = (raw: unknown) => ({
  providerSource: 'mock_or_recorded' as const, cacheHit: false,
  model: 'fixture-model', latencyMillis: 7,
  usage: {inputTokens: 100, outputTokens: 20, thinkingTokens: null, totalTokens: 120},
  text: JSON.stringify(raw),
});
const response = (rows: ReturnType<typeof rank>[]) =>
  inference({rankedCandidateIds: rows.flatMap(row => row.ranking)});
const calfContext: WorkoutRankingContext = {goal:'muscle_gain',experience:'beginner',frequency:'regular',reps:'moderate'};
const calf = [
  candidate('private-calf-publication-a','content',['exercise_match','experience_match','training_frequency']),
  candidate('private-calf-publication-b','content',['exercise_match','experience_match','training_frequency']),
];
const httpResponse = (raw: unknown) => new Response(JSON.stringify({
  candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(raw)}]}}],
  modelVersion:'fixture-model',usageMetadata:{promptTokenCount:100,candidatesTokenCount:20,totalTokenCount:120},
}));

describe('minimal workout ranking contract',()=>{
  it.each([2,3,6])('validates one kind with %i complete anonymous candidates',async count=>{
    const rows=Array.from({length:count},(_,i)=>candidate('private-'+i,'content',['exercise_match']));
    const provider:WorkoutRankingProvider=async request=>inference({
      rankedCandidateIds:request.candidates.map(row=>row.label).reverse(),
    });
    const result=await rankWorkoutRecommendations(provider,calfContext,rows);
    expect(result.failure).toBeUndefined();
    expect(result.selections.content).toMatchObject({method:'gemini',candidate:rows[count-1],ruleFirst:rows[0],changedOrder:true});
    expect(result.selections.content!.ranking).toHaveLength(count);
  });

  it('reproduces the two-candidate Calf input through the actual structured provider transport',async()=>{
    const fetcher=vi.fn(async (_url:Parameters<typeof fetch>[0],init?:RequestInit)=>{
      const body=JSON.parse(String(init?.body));
      const request=JSON.parse(body.contents[0].parts[0].text);
      expect(request.promptVersion).toBe('module13-workout-v2');
      expect(request.candidates.map((row:{label:string})=>row.label)).toEqual(['T1','T2']);
      expect(body.generationConfig.responseSchema).toEqual({
        type:'OBJECT',required:['rankedCandidateIds'],properties:{rankedCandidateIds:{type:'ARRAY',items:{type:'STRING'}}},
      });
      expect(JSON.stringify(body)).not.toContain('private-calf');
      expect(JSON.stringify(body)).not.toMatch(/selectedCandidateId|relevantWorkoutFactors/);
      return httpResponse({rankedCandidateIds:['T2','T1']});
    });
    const provider=createGeminiWorkoutRecommendationRanker({apiKey:'fixture-key',fetcher});
    const output=await rankWorkoutRecommendations(provider,calfContext,calf);
    expect(output.selections.content!.method).toBe('gemini');
    expect(output.selections.content!.candidate.target).toBe('private-calf-publication-b');
    expect(output.selections.content!.factors).toEqual(calf[1].factors);
    expect(fetcher).toHaveBeenCalledTimes(1);
    await rankWorkoutRecommendations(provider,calfContext,calf);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it.each([
    ['missing_required_field',{}],
    ['extra_field',{rankedCandidateIds:['T2','T1'],reason:'invented'}],
    ['invalid_structure',{rankedCandidateIds:'T2'}],
    ['invalid_structure',null],
    ['invalid_candidate_id',{rankedCandidateIds:['T9','T1']}],
    ['invalid_candidate_id',{rankedCandidateIds:['private-calf-publication-a','T1']}],
    ['invalid_candidate_id',{rankedCandidateIds:[2,'T1']}],
    ['duplicate_candidate_id',{rankedCandidateIds:['T1','T1']}],
    ['incomplete_ranking',{rankedCandidateIds:['T2']}],
    ['incomplete_ranking',{rankedCandidateIds:[]}],
  ])('rejects %s and keeps the rule result (%j)',async(code,raw)=>{
    const output=await rankWorkoutRecommendations(async()=>inference(raw),calfContext,calf);
    expect(output.failure).toBe('invalid_provider_output');
    expect(output.validationFailure).toBe(code);
    expect(output.selections.content).toMatchObject({method:'rule_fallback',candidate:calf[0]});
  });

  it('identifies malformed JSON precisely',async()=>{
    const output=await rankWorkoutRecommendations(async()=>({...inference({}),text:'incomplete {'}),calfContext,calf);
    expect(output.validationFailure).toBe('invalid_json');
    expect(output.selections.content!.method).toBe('rule_fallback');
  });

  it('skips the provider when every kind has a single eligible candidate',async()=>{
    const provider=vi.fn<WorkoutRankingProvider>();
    const rows=[calf[0],candidate('coach','trainer',['goal_match']),candidate('routine','routine',[])];
    const output=await rankWorkoutRecommendations(provider,calfContext,rows);
    expect(provider).not.toHaveBeenCalled();
    for(const selection of Object.values(output.selections)){
      expect(selection).toMatchObject({method:'rule_fallback',fallbackReason:'single_eligible_candidate'});
    }
  });

  it('ranks the two-candidate kind while a singleton remains a rule choice',async()=>{
    const provider:WorkoutRankingProvider=async request=>{
      expect(request.candidates.map(row=>row.kind)).toEqual(['content','content']);
      return inference({rankedCandidateIds:['T2','T1']});
    };
    const output=await rankWorkoutRecommendations(provider,calfContext,[...calf,candidate('coach','trainer',['goal_match'])]);
    expect(output.selections.content!.method).toBe('gemini');
    expect(output.selections.trainer).toMatchObject({method:'rule_fallback',fallbackReason:'single_eligible_candidate'});
  });

  it('maps three kinds without returning a type, chosen ID or evidence from the model',async()=>{
    const rows=[...calf,
      candidate('coach-a','trainer',['goal_match']),candidate('coach-b','trainer',['coach_specialization']),
      candidate('routine-a','routine',['experience_match']),candidate('routine-b','routine',['duration_match'])];
    const output=await rankWorkoutRecommendations(async()=>inference({
      rankedCandidateIds:['R2','T2','C2','T1','R1','C1'],
    }),{...calfContext,duration:'short'},rows);
    expect(output.selections.content!.candidate.target).toBe(calf[1].target);
    expect(output.selections.trainer!.candidate.target).toBe('coach-b');
    expect(output.selections.routine!.candidate.target).toBe('routine-b');
    expect(Object.values(output.selections).every(row=>row.method==='gemini')).toBe(true);
  });

  it('ignores unsupported feature claims and never invents a missing preference',async()=>{
    const output=await rankWorkoutRecommendations(async()=>inference({rankedCandidateIds:['T2','T1']}),{},
      [calf[0],candidate('other','content',['goal_match','experience_match','form_practice','exercise_match'])]);
    expect(output.selections.content!.factors).toEqual(['exercise_match']);
    expect(output.selections.content!.reason).not.toMatch(/beginner|muscle|form/i);
  });

  it('retains rule fallback on actual transport timeout',async()=>{
    const provider=createGeminiWorkoutRecommendationRanker({
      apiKey:'fixture',timeoutMillis:10,fetcher:async()=>new Promise<Response>(()=>{}),
    });
    const output=await rankWorkoutRecommendations(provider,calfContext,calf);
    expect(output.failure).toBe('timeout');
    expect(output.selections.content!.method).toBe('rule_fallback');
  });

  it('keeps network errors and quota failure details out of saved reasons',async()=>{
    const provider=createGeminiWorkoutRecommendationRanker({
      apiKey:'fixture',fetcher:async()=>new Response('private provider text',{status:429}),
    });
    const output=await rankWorkoutRecommendations(provider,calfContext,calf);
    expect(output.failure).toBe('rate_limited');
    expect(JSON.stringify(output)).not.toContain('private provider text');
  });

  it('handles all eighteen candidates in one bounded request',async()=>{
    const fetcher=vi.fn(async(_url:Parameters<typeof fetch>[0],init?:RequestInit)=>{
      expect(Buffer.byteLength(String(init?.body))).toBeLessThanOrEqual(8000);
      const request=JSON.parse(JSON.parse(String(init?.body)).contents[0].parts[0].text);
      return httpResponse({rankedCandidateIds:request.candidates.map((row:{label:string})=>row.label).reverse()});
    });
    const rows=(['trainer','content','routine'] as const).flatMap(kind=>
      Array.from({length:6},(_,i)=>candidate(kind+i,kind,[...WORKOUT_RANKING_FACTORS])));
    const output=await rankWorkoutRecommendations(
      createGeminiWorkoutRecommendationRanker({apiKey:'fixture',fetcher}),
      {goal:'strength',experience:'beginner',duration:'short',frequency:'regular'},rows);
    expect(Object.values(output.selections).every(row=>row.method==='gemini')).toBe(true);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('does not invoke the provider with an empty or unavailable candidate set',async()=>{
    const provider=vi.fn<WorkoutRankingProvider>();
    expect((await rankWorkoutRecommendations(provider,{},[])).selections).toEqual({});
    expect((await rankWorkoutRecommendations(undefined,calfContext,calf)).selections.content!.method).toBe('rule_fallback');
    expect(provider).not.toHaveBeenCalled();
  });
});


describe('synthetic Top-1 comparison using hand-authored labels and mocked provider responses', () => {
  it('reports relevance and changed winners without fabricating absent candidates or context', async () => {
    const scenarios: {
      context: WorkoutRankingContext; candidates: WorkoutRankingCandidate<string>[];
      expected: string; mock: ReturnType<typeof rank>; reason: RegExp;
    }[] = [
      {
        context: { experience: 'beginner', frequency: 'new', duration: 'short' },
        candidates: [
          candidate('intro-standard', 'routine', ['experience_match'], { duration: 'long' }),
          candidate('intro-short', 'routine', ['duration_match', 'experience_match'], { duration: 'short' }),
        ], expected: 'intro-short', mock: rank('routine', ['R2', 'R1'], ['duration_match']), reason: /short/i,
      }, {
        context: { goal: 'strength', experience: 'advanced', frequency: 'regular', duration: 'long', form: 'consistent' },
        candidates: [
          candidate('full-strength', 'routine', ['goal_match', 'duration_match'], { duration: 'long' }),
          candidate('light-strength', 'routine', ['goal_match'], { duration: 'medium' }),
        ], expected: 'full-strength', mock: rank('routine', ['R1', 'R2'], ['goal_match']), reason: /strength/i,
      }, {
        context: { goal: 'general_fitness', experience: 'beginner', frequency: 'occasional', form: 'developing', exercise: 'lower_body' },
        candidates: [
          candidate('higher-difficulty', 'content', ['exercise_match'], { difficulty: 'advanced' }),
          candidate('movement-practice', 'content', ['exercise_match', 'form_practice'], { difficulty: 'beginner' }),
        ], expected: 'movement-practice', mock: rank('content', ['T2', 'T1'], ['form_practice']), reason: /movement control/i,
      }, {
        context: { goal: 'strength', frequency: 'regular', completion: 'completed', reps: 'high' },
        candidates: [
          candidate('general-coach', 'trainer', ['goal_match']),
          candidate('specific-coach', 'trainer', ['goal_match', 'coach_specialization', 'repetition_volume']),
        ], expected: 'specific-coach', mock: rank('trainer', ['C2', 'C1'], ['coach_specialization', 'goal_match']), reason: /strength/i,
      }, {
        context: { frequency: 'new', completion: 'partial', reps: 'low', duration: 'medium' },
        candidates: [
          candidate('mid-length', 'routine', ['duration_match', 'completion'], { duration: 'medium' }),
          candidate('long-workout', 'routine', ['completion'], { duration: 'long' }),
        ], expected: 'mid-length', mock: rank('routine', ['R1', 'R2'], ['duration_match', 'completion']), reason: /unfinished/i,
      },
    ];
    let ruleCorrect = 0;
    let mockCorrect = 0;
    let changedWinners = 0;
    let calls = 0;
    const ruleMillis: number[] = [];
    const mockMillis: number[] = [];
    for (const sample of scenarios) {
      const kind = sample.candidates[0].kind;
      const start = performance.now();
      const baseline = await rankWorkoutRecommendations(undefined, sample.context, sample.candidates);
      const baselineEnded = performance.now();
      const gemini = await rankWorkoutRecommendations(async () => {
        calls += 1;
        return response([sample.mock]);
      }, sample.context, sample.candidates);
      ruleMillis.push(baselineEnded - start);
      mockMillis.push(performance.now() - baselineEnded);
      const baselinePick = baseline.selections[kind]?.candidate.target;
      const mockPick = gemini.selections[kind]?.candidate.target;
      ruleCorrect += Number(baselinePick === sample.expected);
      mockCorrect += Number(mockPick === sample.expected);
      changedWinners += Number(baselinePick !== mockPick);
      expect(sample.candidates).toContain(gemini.selections[kind]?.candidate);
      expect(gemini.selections[kind]?.reason).toMatch(sample.reason);
      for (const absentKind of ['trainer', 'content', 'routine'] as const) {
        if (absentKind !== kind) expect(gemini.selections[absentKind]).toBeUndefined();
      }
    }
    const unused = vi.fn<WorkoutRankingProvider>();
    expect((await rankWorkoutRecommendations(unused, {}, [])).selections).toEqual({});
    expect(unused).not.toHaveBeenCalled();
    expect({ ruleCorrect, mockCorrect, changedWinners, calls }).toEqual({
      ruleCorrect: 2, mockCorrect: 5, changedWinners: 3, calls: 5,
    });
    console.info(JSON.stringify({
      measurement: 'hand_authored_fixture_with_mocked_gemini',
      scenarios: scenarios.length, ruleCorrect, mockCorrect, changedWinners, calls,
      averageRuleMillis: ruleMillis.reduce((sum, value) => sum + value, 0) / scenarios.length,
      averageMockMillis: mockMillis.reduce((sum, value) => sum + value, 0) / scenarios.length,
      realProviderCalls: 0,
    }));
  });
});
