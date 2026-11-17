import { describe, expect, it, vi } from 'vitest';
import {
  createGeminiWorkoutRecommendationRanker, rankWorkoutRecommendations,
  WORKOUT_RANKING_FACTORS,
  type WorkoutRankingCandidate, type WorkoutRankingContext, type WorkoutRankingFactor,
  type WorkoutRankingProvider,
} from '../src/modules/recommendation/workout-recommendation-ranking';

const candidate = (id: string, kind: WorkoutRankingCandidate<string>['kind'],
  factors: WorkoutRankingFactor[], detail: Partial<WorkoutRankingCandidate<string>> = {}): WorkoutRankingCandidate<string> =>
  ({ kind, target: id, factors, ...detail });

const rank = (recommendationType: string, ranking: string[], relevantWorkoutFactors: string[]) =>
  ({ recommendationType, selectedCandidateId: ranking[0], ranking, relevantWorkoutFactors });

const response = (recommendations: unknown[]) => ({
  providerSource: 'mock_or_recorded' as const, cacheHit: false,
  model: 'gemini-3.5-flash-lite-fixture', latencyMillis: 42,
  usage: { inputTokens: 325, outputTokens: 105, thinkingTokens: 10, totalTokens: 440 },
  text: JSON.stringify({ recommendations }),
});

const httpResponse = (recommendations: unknown[]): Response => {
  const inference = response(recommendations);
  return new Response(JSON.stringify({
    modelVersion: inference.model, candidates: [{ finishReason: 'STOP', content: { parts: [{ text: inference.text }] } }],
    usageMetadata: { promptTokenCount: 325, candidatesTokenCount: 105, thoughtsTokenCount: 10, totalTokenCount: 440 },
  }));
};

describe('production workout ranking', () => {
  it('uses one bounded structured request and alters all three destinations with grounded reasons', async () => {
    const candidates = [
      candidate('private-baseline-video', 'content', ['exercise_match']),
      candidate('private-new-video', 'content', ['exercise_match', 'form_practice'], { difficulty: 'beginner' }),
      candidate('private-baseline-coach', 'trainer', ['goal_match']),
      candidate('private-new-coach', 'trainer', ['coach_specialization', 'goal_match']),
      candidate('private-baseline-routine', 'routine', ['goal_match'], { duration: 'long' }),
      candidate('private-new-routine', 'routine', ['goal_match', 'duration_match'], { duration: 'short' }),
    ];
    const context: WorkoutRankingContext = {
      goal: 'strength', experience: 'beginner', exercise: 'lower_body', duration: 'short', form: 'developing',
    };
    // Emulate extra input from a server object. Only the allowlisted nested fields cross the boundary.
    Object.assign(context, { bmi: 26, name: 'Private Member' });
    Object.assign(candidates[1], { notes: 'Private notes' });
    const fetcher = vi.fn(async (_resource: Parameters<typeof fetch>[0], init?: RequestInit) => {
      const body = JSON.parse(String(init?.body));
      const payload = JSON.parse(body.contents[0].parts[0].text);
      expect(payload.context).toEqual({
        goal: 'strength', experience: 'beginner', exercise: 'lower_body', duration: 'short', form: 'developing',
      });
      expect(JSON.stringify(payload)).not.toMatch(/private|bmi|notes/i);
      expect(body.generationConfig).toMatchObject({ maxOutputTokens: 512, responseMimeType: 'application/json' });
      expect(body.generationConfig.responseSchema.properties.recommendations.items.required).toContain('ranking');
      expect(body.tools).toBeUndefined();
      expect(Buffer.byteLength(String(init?.body))).toBeLessThan(5000);
      return httpResponse([
        rank('content', ['T2', 'T1'], ['form_practice', 'exercise_match']),
        rank('trainer', ['C2', 'C1'], ['coach_specialization', 'goal_match']),
        rank('routine', ['R2', 'R1'], ['duration_match', 'goal_match']),
      ]);
    });
    const provider = createGeminiWorkoutRecommendationRanker({ apiKey: 'fixture-key', fetcher });
    const result = await rankWorkoutRecommendations(provider, context, candidates);

    expect(fetcher).toHaveBeenCalledTimes(1);
    for (const [kind, index] of [['content', 1], ['trainer', 3], ['routine', 5]] as const) {
      expect(result.selections[kind]).toMatchObject({ candidate: candidates[index], method: 'gemini', changedOrder: true });
      expect(result.selections[kind]?.ranking.map(entry => entry.target)).toEqual([
        candidates[index].target, candidates[index - 1].target,
      ]);
    }
    expect(result.selections.content?.reason).toMatch(/movement control/i);
    expect(result.selections.trainer?.reason).toMatch(/strength/i);
    expect(result.selections.routine?.reason).toMatch(/short/i);
    expect(result.inference).toMatchObject({
      providerSource: 'mock_or_recorded', model: 'gemini-3.5-flash-lite-fixture', cacheHit: false,
      usage: { inputTokens: 325, outputTokens: 105, thinkingTokens: 10, totalTokens: 440 },
    });

    const cached = await rankWorkoutRecommendations(provider, context, candidates);
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(cached.inference).toMatchObject({ cacheHit: true, usage: { totalTokens: 0 } });
  });

  it.each([
    rank('content', ['T9', 'T1'], ['exercise_match']),
    rank('content', ['T2', 'C1'], ['exercise_match']),
    rank('content', ['T2', 'T2'], ['exercise_match']),
    rank('content', ['T2'], ['exercise_match']),
    rank('content', ['T2', 'T1'], ['repetition_volume']),
    { ...rank('content', ['T2', 'T1'], ['exercise_match']), personalizedReason: 'You hurt your knee.' },
    { ...rank('content', ['T2', 'T1'], ['exercise_match']), selectedCandidateId: 'T1' },
  ])('uses rules for an invalid kind and honors a valid subset (%j)', async invalid => {
    const provider: WorkoutRankingProvider = async () => response([
      invalid, rank('routine', ['R2', 'R1'], ['experience_match']),
    ]);
    const output = await rankWorkoutRecommendations(provider, { experience: 'beginner' }, [
      candidate('baseline-tutorial', 'content', ['exercise_match']),
      candidate('alternate-tutorial', 'content', ['exercise_match']),
      candidate('baseline-routine', 'routine', []),
      candidate('alternate-routine', 'routine', ['experience_match']),
    ]);

    expect(output.failure).toBe('invalid_provider_output');
    expect(output.selections.content).toMatchObject({ method: 'rule_fallback', candidate: { target: 'baseline-tutorial' } });
    expect(output.selections.routine).toMatchObject({ method: 'gemini', candidate: { target: 'alternate-routine' } });
    expect(output.selections.trainer).toBeUndefined();
  });

  it('rejects duplicate kinds without discarding valid kinds', async () => {
    const provider: WorkoutRankingProvider = async () => response([
      rank('content', ['T1'], ['exercise_match']),
      rank('content', ['T1'], ['exercise_match']),
      rank('routine', ['R1'], ['exercise_match']),
    ]);

    const result = await rankWorkoutRecommendations(provider, {}, [
      candidate('video', 'content', ['exercise_match']),
      candidate('routine', 'routine', ['exercise_match']),
    ]);
    expect(result.selections.content?.method).toBe('rule_fallback');
    expect(result.selections.routine?.method).toBe('gemini');
    expect(result.failure).toBe('invalid_provider_output');
  });

  it('caps candidates per kind and rejects fabricated context and factors from raw calls', async () => {
    const fetcher = vi.fn(async () => httpResponse([]));
    const provider = createGeminiWorkoutRecommendationRanker({ apiKey: 'fixture-key', fetcher });
    const inspect: WorkoutRankingProvider = async request => {
      expect(request.candidates).toHaveLength(6);
      expect(request.context).toEqual({ completion: 'completed' });
      expect(request.candidates[0].factors).toEqual(['completion']);
      await expect(provider({
        ...request, context: { ...request.context, goal: 'My private training note' },
      } as unknown as typeof request)).rejects.toMatchObject({ reason: 'invalid_request' });
      await expect(provider({
        ...request, candidates: request.candidates.map(entry => ({ ...entry, factors: [' private note'] })),
      } as unknown as typeof request)).rejects.toMatchObject({ reason: 'invalid_request' });
      return response([]);
    };
    const result = await rankWorkoutRecommendations(inspect,
      { goal: 'Private note', completion: 'completed' } as unknown as WorkoutRankingContext,
      Array.from({ length: 8 }, (_, i) => candidate(String(i), 'routine', ['completion', 'form_practice'])));
    expect(result.selections.routine?.ranking).toHaveLength(6);
    expect(result.selections.routine?.candidate.target).toBe('0');
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('falls back promptly on timeout and keeps quota failures out of suggestion text', async () => {
    let signal: AbortSignal | null | undefined;
    const slow = vi.fn((_resource: Parameters<typeof fetch>[0], init?: RequestInit): Promise<Response> => {
      signal = init?.signal;
      return new Promise(() => {});
    });
    const providers = [
      createGeminiWorkoutRecommendationRanker({ apiKey: 'fixture-key', timeoutMillis: 10, fetcher: slow }),
      createGeminiWorkoutRecommendationRanker({
        apiKey: 'fixture-key',
        fetcher: async () => new Response('private provider details', { status: 429 }),
      }),
    ];
    const candidates = [candidate('published', 'content', ['exercise_match'])];
    for (const [i, provider] of providers.entries()) {
      const result = await rankWorkoutRecommendations(provider, {}, candidates);
      expect(result).toMatchObject({
        failure: i === 0 ? 'timeout' : 'rate_limited',
        selections: { content: { candidate: candidates[0], method: 'rule_fallback', changedOrder: false } },
      });
      expect(result.inference).toBeUndefined();
      expect(JSON.stringify(result)).not.toContain('private provider details');
    }
    expect(slow).toHaveBeenCalledTimes(1);
    expect(signal?.aborted).toBe(true);
  });

  it('keeps the production rate budget bounded and resets it after a minute', async () => {
    let now = 0;
    const fetcher = vi.fn(async () => httpResponse([rank('content', ['T1'], ['exercise_match'])]));
    const provider = createGeminiWorkoutRecommendationRanker({ apiKey: 'fixture-key', fetcher, clock: () => now, maxRequests: 1 });
    const candidates = [candidate('pub-tutorial', 'content', ['exercise_match'])];
    await rankWorkoutRecommendations(provider, { exercise: 'lower_body' }, candidates);
    const capped = await rankWorkoutRecommendations(provider, { exercise: 'upper_body' }, candidates);
    expect(capped.failure).toBe('rate_limited');
    expect(fetcher).toHaveBeenCalledTimes(1);
    now = 60000;
    await rankWorkoutRecommendations(provider, { exercise: 'upper_body' }, candidates);
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('sends the maximum real candidate mix in one compact request', async () => {
    const recommendations = ['trainer', 'content', 'routine'].map((kind, index) =>
      rank(kind, Array.from({ length: 6 }, (_, i) => ['C', 'T', 'R'][index] + (i + 1)),
        ['experience_match', 'duration_match']));
    const fetcher = vi.fn(async (_resource: Parameters<typeof fetch>[0], init?: RequestInit) => {
      expect(Buffer.byteLength(String(init?.body))).toBeLessThanOrEqual(5000);
      return httpResponse(recommendations);
    });
    const candidates = (['trainer', 'content', 'routine'] as const).flatMap(kind =>
      Array.from({ length: 6 }, (_, i) => candidate(kind + i, kind,
        ['exercise_match', 'experience_match', 'duration_match', 'goal_match'],
        { duration: 'short', difficulty: 'beginner' })));
    const result = await rankWorkoutRecommendations(
      createGeminiWorkoutRecommendationRanker({ apiKey: 'fixture', fetcher }),
      { experience: 'beginner', duration: 'short', goal: 'strength', exercise: 'lower_body' }, candidates,
    );
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(result.failure).toBeUndefined();
    expect(Object.values(result.selections).every(selection => selection.method === 'gemini')).toBe(true);
  });

  it('falls back for malformed JSON, unsupported wrappers and rejected network calls', async () => {
    const providers: WorkoutRankingProvider[] = [
      async () => ({ ...response([]), text: 'incomplete {' }),
      async () => ({ ...response([]), text: JSON.stringify({ recommendations: [], member: 'private' }) }),
      async () => { throw Error('private network detail'); },
    ];
    for (const provider of providers) {
      const output = await rankWorkoutRecommendations(provider, {}, [candidate('video', 'content', ['exercise_match'])]);
      expect(output.selections.content).toMatchObject({ method: 'rule_fallback', candidate: { target: 'video' } });
      expect(output.failure).toBeDefined();
      expect(JSON.stringify(output)).not.toContain('private');
    }
  });

  it('handles all supported bounded features on all eighteen candidates', async () => {
    let requestBytes = 0;
    const fetcher = vi.fn(async (_resource: Parameters<typeof fetch>[0], init?: RequestInit) => {
      requestBytes = Buffer.byteLength(String(init?.body));
      return httpResponse(['trainer', 'content', 'routine'].map((kind, index) =>
        rank(kind, Array.from({ length: 6 }, (_, i) => ['C', 'T', 'R'][index] + (i + 1)), ['goal_match'])));
    });
    const candidates = (['trainer', 'content', 'routine'] as const).flatMap(kind =>
      Array.from({ length: 6 }, (_, i) => candidate(kind + i, kind, [...WORKOUT_RANKING_FACTORS],
        { duration: 'medium', difficulty: 'intermediate' })));
    const result = await rankWorkoutRecommendations(
      createGeminiWorkoutRecommendationRanker({ apiKey: 'fixture', fetcher }), {
        goal: 'strength', experience: 'intermediate', frequency: 'regular', completion: 'completed',
        reps: 'high', form: 'consistent', duration: 'medium', exercise: 'full_body', equipment: 'dumbbells',
      }, candidates,
    );
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(result.failure).toBeUndefined();
    expect(requestBytes).toBeLessThanOrEqual(8000);
    console.info(JSON.stringify({ measurement: 'mocked_maximum_workout_ranking_input', requestBytes, candidates: 18 }));
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
