import { describe, it, expect, vi } from 'vitest';
import { runGemini, validateInput, TOOL_REGISTRY, personalMetricsIntent, unsupportedPersonalMetrics } from '../src/modules/chatbot/chatbot-service';

describe('fitness assistant boundaries', () => {
  it('supports discovery, current options and an unreserved proposal over bounded model turns',async()=>{
    const calls=['list_coaches','get_coaching_options','propose_booking'];
    const args=[{}, {coachId:'coach-1',durationMinutes:60}, {coachId:'coach-1',durationMinutes:60,localDate:'2026-10-23',branchId:'branch-1',startAtMillis:1792717200000}];
    const fetcher=vi.fn();
    calls.forEach((name,i)=>fetcher.mockResolvedValueOnce({ok:true,json:async()=>({candidates:[{content:{role:'model',parts:[{functionCall:{name,args:args[i]}}]}}]})}));
    fetcher.mockResolvedValueOnce({ok:true,json:async()=>({candidates:[{content:{parts:[{text:'Review this proposed time.'}]}}]})});
    const execute=vi.fn(async()=>({bookingCreated:false}));
    expect(await runGemini('key','Find a coaching session',[],execute,fetcher)).toBe('Review this proposed time.');
    expect(execute.mock.calls.map(c=>(c as unknown[])[0])).toEqual(calls);
  });
  it('rejects unbounded history and identity fields', () => {
    expect(() => validateInput({ organizationId: 'gym', action: 'reply', text: 'Hi', memberId: 'other' })).toThrow();
    expect(() => validateInput({ organizationId: 'gym', action: 'reply', text: 'Hi', history: Array(21).fill({ role: 'user', text: 'Hi' }) })).toThrow();
    expect(TOOL_REGISTRY.every(tool => tool.readOnly)).toBe(true);
  });
  it('preserves signed model parts while returning scoped function responses', async () => {
    const content = { role: 'model', parts: [{ thoughtSignature: 'opaque', functionCall: { name: 'find_equipment', args: {} } }] };
    const fetcher = vi.fn().mockResolvedValueOnce({ ok: true, json: async () => ({ candidates: [{ content }] }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: 'Keep going.' }] } }] }) });
    expect(await runGemini('key', 'Hello', [], async () => ({ sessions: 2 }), fetcher)).toBe('Keep going.');
    expect(JSON.parse(fetcher.mock.calls[1][1].body).contents[1]).toEqual(content);
  });
  it('rejects unknown tools, injected identifiers, and upstream failures safely', async () => {
    for (const functionCall of [{ name: 'delete_account', args: {} }, { name: 'get_my_progress', args: { uid: 'other' } }]) {
      const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ functionCall }] } }] }) });
      await expect(runGemini('key', 'Hi', [], async () => ({}), fetcher)).rejects.toThrow('Assistant is temporarily unavailable');
    }
  });
  it('maps quota/billing failures and sanitizes empty, blocked and timed-out output', async () => {
    for (const [status, code] of [[429, 'resource-exhausted'], [402, 'failed-precondition'], [503, 'unavailable']] as const) {
      await expect(runGemini('key', 'Hi', [], async () => ({}), vi.fn().mockResolvedValue({ ok: false, status }))).rejects.toMatchObject({ code });
    }
    for (const body of [{ candidates: [] }, { promptFeedback: { blockReason: 'SAFETY' } }, { candidates: [{ content: { parts: [{ text: '' }] } }] }]) {
      await expect(runGemini('key', 'Hi', [], async () => ({}), vi.fn().mockResolvedValue({ ok: true, json: async () => body }))).rejects.toMatchObject({ code: 'unavailable' });
    }
    await expect(runGemini('key', 'Hi', [], async () => ({}), vi.fn().mockRejectedValue(new Error('SECRET detail')))).rejects.toThrow('Assistant is temporarily unavailable');
  });
  it('rejects forged or unbounded device progress', () => {
    expect(() => validateInput({ organizationId: 'gym', action: 'reply', text: 'Hi', deviceProgress: { sessions: [{ sessionId: 's', uid: 'other' }] } })).toThrow();
    expect(() => validateInput({ organizationId: 'gym', action: 'reply', text: 'Hi', deviceProgress: { sessions: Array(31).fill({}) } })).toThrow();
  });
  it('defaults to public tools and omits all previous personal history', async () => {
    vi.stubEnv('GEMINI_CHAT_DATA_MODE', 'public');
    const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: 'Warm up gently.' }] } }] }) });
    await runGemini('key', 'Explain a warm-up', [{ role: 'assistant', text: 'PRIVATE: you completed 456 sessions' }], async () => ({ privateDeviceFact: 999 }), fetcher);
    const payload = fetcher.mock.calls[0][1].body;
    expect(payload).not.toContain('PRIVATE'); expect(payload).not.toContain('456'); expect(payload).not.toContain('privateDeviceFact');
    expect(JSON.parse(payload).tools[0].functionDeclarations.map((t: any) => t.name)).toEqual(['find_equipment', 'list_coaches', 'get_coaching_options', 'propose_booking']);
    vi.unstubAllEnvs();
  });
  it('rejects personal tools before execution or a second provider turn in public mode', async () => {
    vi.stubEnv('GEMINI_CHAT_DATA_MODE', 'public');
    const execute = vi.fn();
    const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ functionCall: { name: 'get_my_progress', args: {} } }] } }] }) });
    await expect(runGemini('key', 'Explain warming up', [], execute, fetcher)).rejects.toMatchObject({ code: 'unavailable' });
    expect(execute).not.toHaveBeenCalled(); expect(fetcher).toHaveBeenCalledOnce();
    vi.unstubAllEnvs();
  });
  it('keeps PII and personal measurement disclosures away from the provider', async () => {
    vi.stubEnv('GEMINI_CHAT_DATA_MODE', 'public');
    for (const text of ['Email me at person@example.com', 'I weigh 92 kg, suggest training', 'I have diabetes, suggest a plan', 'My phone is +60123456789']) {
      const fetcher = vi.fn();
      expect(await runGemini('key', text, [], async () => ({}), fetcher)).toContain('general fitness question');
      expect(fetcher).not.toHaveBeenCalled();
    }
    vi.unstubAllEnvs();
  });
  it('permits personal tools/history only with explicit private-approved server configuration', async () => {
    vi.stubEnv('GEMINI_CHAT_DATA_MODE', 'private-approved');
    const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: 'Okay.' }] } }] }) });
    await runGemini('key', 'Explain a warm-up', [{ role: 'assistant', text: 'PRIVATE_HISTORY' }], async () => ({}), fetcher);
    const payload = JSON.parse(fetcher.mock.calls[0][1].body);
    expect(payload.contents[0].parts[0].text).toBe('PRIVATE_HISTORY');
    expect(payload.tools[0].functionDeclarations.map((t: any) => t.name)).toContain('get_my_progress');
    vi.unstubAllEnvs();
  });
});

it('keeps generic progressive-overload and planned reps questions on the real AI path', () => {
 expect(personalMetricsIntent('Explain progressive overload')).toBe(false);
 expect(personalMetricsIntent('How many reps should I do for a beginner workout?')).toBe(false);
 expect(personalMetricsIntent('How many workouts have I completed?')).toBe(true);
});

it('requires evidence for present-tense personal numeric and spelled-out measurements', () => {
 for(const text of ['You have 99 reps.', 'Your best deadlift is 200 kg.', 'Your total is twelve repetitions.']) expect(unsupportedPersonalMetrics(text)).toBe(true);
 expect(unsupportedPersonalMetrics('You could do 3 sets of 12 repetitions.')).toBe(false);
});
