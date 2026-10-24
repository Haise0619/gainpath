import { describe, expect, it, vi } from 'vitest';
import { fitnessAssistantHandler, fitnessAssistantCommand } from '../src/modules/chatbot/chatbot-callable';
function fixture() {
  const records: Record<string, any> = {
    'users/u': { organizationId: 'g' }, 'orgs/g': { status: 'active' },
    'orgs/g/members/u': { organizationId: 'g', role: 'member', status: 'active', branchIds: [] },
    'orgs/g/chatbotDisclaimer/config': { text: 'Education only.', revision: 2, isActive: true },
  };
  const set = vi.fn((path: string, data: any) => { records[path] = data; });
  const db = { doc: (p: string) => p, runTransaction: async (fn: any) => fn({ getAll: async (...paths: string[]) => paths.map(p => ({ data: () => records[p] })), set }), collection: vi.fn(() => ({ where: () => ({ limit: () => ({ get: async () => ({ docs: [], size: 0 }) }) }) })) } as any;
  const request = (data: any) => ({ app: { appId: 'app' }, auth: { uid: 'u', token: { email_verified: true } }, data: { organizationId: 'g', ...data } }) as any;
  return { records, set, db, request };
}
describe('fitness assistant actual handler', () => {
  it('binds secret and rejects missing App Check/auth', async () => {
    expect(fitnessAssistantCommand.__endpoint.secretEnvironmentVariables).toContainEqual(expect.objectContaining({ key: 'GEMINI_API_KEY' }));
    await expect(fitnessAssistantHandler({ data: {} } as any)).rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(fitnessAssistantHandler({ app: {}, data: {} } as any)).rejects.toMatchObject({ code: 'unauthenticated' });
  });
  it('requires canonical active member, organization and current disclaimer acknowledgement', async () => {
    const f = fixture();
    await expect(fitnessAssistantHandler(f.request({ action: 'reply', text: 'Hi' }), { db: f.db })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(fitnessAssistantHandler(f.request({ action: 'acknowledge', disclaimerRevision: 1 }), { db: f.db })).rejects.toMatchObject({ code: 'failed-precondition' });
    f.records['users/u'].organizationId = 'other';
    await expect(fitnessAssistantHandler(f.request({ action: 'bootstrap' }), { db: f.db })).rejects.toMatchObject({ code: 'permission-denied' });
  });
  it('stores only explicit bookmarks, feedback, acknowledgement and limiter, never conversation', async () => {
    const f = fixture();
    await fitnessAssistantHandler(f.request({ action: 'acknowledge', disclaimerRevision: 2 }), { db: f.db });
    const response: any = await fitnessAssistantHandler(f.request({ action: 'reply', text: 'My progress', deviceProgress: { sessions: [{ sessionId: 's', startedAtMillis: Date.now() - 20000, endedAtMillis: Date.now() - 10000, repetitions: 12, formScorePercent: 80 }] } }), { db: f.db });
    expect(response.text).toContain('device additionally reports 1 sessions and 12 repetitions');
    expect(response.text).toContain('unverified');
    expect(JSON.stringify(f.records)).not.toContain('My progress');
    await fitnessAssistantHandler(f.request({ action: 'bookmark', text: response.text }), { db: f.db });
    await fitnessAssistantHandler(f.request({ action: 'rate', responseId: response.responseId, helpful: true }), { db: f.db });
    const state = f.records['orgs/g/members/u/chatbot/state'];
    expect(state.bookmarks).toEqual([response.text]);
    expect(state.ratings[0].helpful).toBe(true);
    expect(f.set.mock.calls.every(([path]) => path === 'orgs/g/members/u/chatbot/state')).toBe(true);
  });
  it('limits replies across requests using persisted state before upstream calls', async () => {
    const f = fixture();
    f.records['orgs/g/members/u/chatbot/state'] = { acknowledgedRevision: 2, rateWindowMillis: Date.now(), rateCount: 10 };
    await expect(fitnessAssistantHandler(f.request({ action: 'reply', text: 'Hi' }), { db: f.db })).rejects.toMatchObject({ code: 'resource-exhausted' });
  });
  it('rejects nonmembers, inactive config, unverified email and stale lifecycle sessions', async () => {
    for (const change of [
      (f: ReturnType<typeof fixture>) => { f.records['orgs/g/members/u'].role = 'coach'; },
      (f: ReturnType<typeof fixture>) => { f.records['orgs/g/members/u'].status = 'pendingDeletion'; },
      (f: ReturnType<typeof fixture>) => { f.records['orgs/g'].status = 'inactive'; },
      (f: ReturnType<typeof fixture>) => { f.records['users/u'].accountLifecycle = { state: 'active', sessionNotBeforeSeconds: 100 }; },
    ]) {
      const f = fixture(); change(f);
      await expect(fitnessAssistantHandler(f.request({ action: 'bootstrap' }), { db: f.db })).rejects.toMatchObject({ code: 'permission-denied' });
    }
    const f = fixture();
    f.records['orgs/g/chatbotDisclaimer/config'].isActive = false;
    await expect(fitnessAssistantHandler(f.request({ action: 'bootstrap' }), { db: f.db })).rejects.toMatchObject({ code: 'failed-precondition' });
    const request = f.request({ action: 'bootstrap' }); request.auth.token.email_verified = false;
    await expect(fitnessAssistantHandler(request, { db: f.db })).rejects.toMatchObject({ code: 'permission-denied' });
  });
  it('bounds bookmark and ratings cardinality and keeps workout planning on AI path', async () => {
    const f = fixture();
    f.records['orgs/g/members/u/chatbot/state'] = { acknowledgedRevision: 2, bookmarks: Array.from({ length: 50 }, (_, i) => `saved ${i}`), ratings: Array.from({ length: 100 }, (_, i) => ({ responseId: `r${i}`, helpful: true, atMillis: 1 })) };
    await fitnessAssistantHandler(f.request({ action: 'bookmark', text: 'new bookmark' }), { db: f.db });
    await fitnessAssistantHandler(f.request({ action: 'rate', responseId: 'new', helpful: false }), { db: f.db });
    expect(f.records['orgs/g/members/u/chatbot/state'].bookmarks).toHaveLength(50);
    expect(f.records['orgs/g/members/u/chatbot/state'].ratings).toHaveLength(100);
    const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: 'Start with a comfortable warm-up.' }] } }] }) });
    const result: any = await fitnessAssistantHandler(f.request({ action: 'reply', text: 'Plan my workout' }), { db: f.db, apiKey: 'key', fetcher });
    expect(result.text).toBe('Start with a comfortable warm-up.'); expect(fetcher).toHaveBeenCalledOnce();
  });
  it('rechecks revocation before tool reads and before returning provider text', async () => {
    for (const tool of [true, false]) {
      const f = fixture();
      f.records['orgs/g/members/u/chatbot/state'] = { acknowledgedRevision: 2 };
      const fetcher = vi.fn().mockImplementation(async () => {
        f.records['orgs/g/members/u'].status = 'pendingDeletion';
        return { ok: true, json: async () => ({ candidates: [{ content: { parts: tool ? [{ functionCall: { name: 'find_equipment', args: {} } }] : [{ text: 'Here is your advice.' }] } }] }) };
      });
      await expect(fitnessAssistantHandler(f.request({ action: 'reply', text: 'Tell me about equipment' }), { db: f.db, apiKey: 'key', fetcher })).rejects.toMatchObject({ code: 'permission-denied' });
      expect(f.db.collection).not.toHaveBeenCalled();
    }
  });
  it('uses facts for personal count questions and replaces unsupported provider metrics', async () => {
    const f = fixture();
    f.records['orgs/g/members/u/chatbot/state'] = { acknowledgedRevision: 2 };
    const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: 'You completed 999 sessions.' }] } }] }) });
    const direct: any = await fitnessAssistantHandler(f.request({ action: 'reply', text: 'How many workouts have I completed?' }), { db: f.db, apiKey: 'key', fetcher });
    expect(fetcher).not.toHaveBeenCalled(); expect(direct.text).toContain('0 accepted workout sessions');
    const invented: any = await fitnessAssistantHandler(f.request({ action: 'reply', text: 'Encourage me today' }), { db: f.db, apiKey: 'key', fetcher });
    expect(invented.text).not.toContain('999'); expect(invented.sources).toContain('get_my_progress');
    fetcher.mockResolvedValue({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: 'Try 3 sets of 12 repetitions with a comfortable load.' }] } }] }) });
    const plan: any = await fitnessAssistantHandler(f.request({ action: 'reply', text: 'Plan my workout' }), { db: f.db, apiKey: 'key', fetcher });
    expect(plan.text).toContain('3 sets of 12');
  });
  it('guards historical distance questions and spelled-out personal activity claims', async () => {
    const f = fixture();
    f.records['orgs/g/members/u/chatbot/state'] = { acknowledgedRevision: 2 };
    const fetcher = vi.fn();
    const distance: any = await fitnessAssistantHandler(f.request({ action: 'reply', text: 'How far did I run yesterday?' }), { db: f.db, apiKey: 'key', fetcher });
    expect(fetcher).not.toHaveBeenCalled();
    expect(distance.text).toContain('Distance, calories burned, weight changes, and other measurements are unavailable');
    for (const claim of ['You ran 5 km yesterday.', 'You completed twelve sessions.', 'You walked five miles.', 'You burned many calories.', 'Your recovery improved last week.']) {
      fetcher.mockResolvedValue({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: claim }] } }] }) });
      const result: any = await fitnessAssistantHandler(f.request({ action: 'reply', text: 'Encourage me today' }), { db: f.db, apiKey: 'key', fetcher });
      expect(result.text).not.toBe(claim); expect(result.sources).toContain('get_my_progress');
    }
  });
});
