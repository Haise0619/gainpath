import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { identifyEquipmentWithGemini, identifyEquipmentCommand } from '../src/modules/workouts/equipment-scanner-callable';
import { HttpsError } from 'firebase-functions/v2/https';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { createRequire } from 'node:module';

const db = vi.hoisted(() => ({ doc: vi.fn((path: string) => path), getAll: vi.fn() }));
vi.mock('firebase-admin/firestore', () => ({ getFirestore: () => db }));
const registration = vi.hoisted(() => ({ options: {} as Record<string, unknown> }));
vi.mock('firebase-functions/v2/https', async importOriginal => {
  const actual = await importOriginal<typeof import('firebase-functions/v2/https')>();
  return { ...actual, onCall: (options: any, handler: any) => {
    registration.options = options;
    return actual.onCall(options, handler);
  } };
});

describe('equipment-scanner-callable', () => {
  beforeEach(() => { vi.stubEnv('GEMINI_API_KEY', 'test-only-key'); });
  afterEach(() => { vi.unstubAllEnvs(); vi.unstubAllGlobals(); });
  it('binds the secret and enforces App Check on the deployed callable', () => {
    expect(identifyEquipmentCommand.__endpoint.secretEnvironmentVariables).toContainEqual(expect.objectContaining({ key: 'GEMINI_API_KEY' }));
    expect(registration.options.enforceAppCheck).toBe(true);
  });

  it('rejects missing auth and App Check through the actual HTTP callable wrapper', async () => {
    // Use the same Express request/response contract as Firebase's HTTP host.
    const express = createRequire(require.resolve('firebase-functions'))('express');
    const app = express();
    app.use(express.json());
    app.post('/', identifyEquipmentCommand);
    const server = createServer(app);
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    try {
      const address = server.address() as { port: number };
      const response = await fetch(`http://127.0.0.1:${address.port}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: { organizationId: 'gainpath', imageBase64: '/9j/AA==' } }),
      });
      expect(response.status).toBe(401);
      expect(await response.json()).toMatchObject({ error: { status: 'UNAUTHENTICATED' } });
    } finally {
      await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    }
  });

  it('rejects an unauthenticated callable request before inference', async () => {
    await expect(identifyEquipmentCommand.run({ data: {} } as any)).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('rejects unverified callers before inference', async () => {
    await expect(identifyEquipmentCommand.run({ data: {}, auth: { uid: 'member', token: { email_verified: false } } } as any)).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it.each([
    [{ organizationId: 'other' }, { role: 'member', status: 'active', branchIds: [] }],
    [{ organizationId: 'gainpath' }, { role: 'coach', status: 'active', branchIds: [] }],
    [{ organizationId: 'gainpath' }, { role: 'member', status: 'suspended', branchIds: [] }],
    [{ organizationId: 'gainpath' }, undefined],
  ])('rejects ineligible organization membership %#', async (user, membership) => {
    db.getAll.mockResolvedValue([{ data: () => user }, { data: () => membership }]);
    await expect(identifyEquipmentCommand.run({ data: { organizationId: 'gainpath' }, auth: { uid: 'member', token: { email_verified: true } } } as any)).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('allows an eligible member to reach payload validation using scoped documents', async () => {
    db.getAll.mockResolvedValue([{ data: () => ({ organizationId: 'gainpath' }) }, { data: () => ({ role: 'member', status: 'active', branchIds: [] }) }]);
    await expect(identifyEquipmentCommand.run({ data: { organizationId: 'gainpath' }, auth: { uid: 'member', token: { email_verified: true } } } as any)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(db.getAll).toHaveBeenLastCalledWith('users/member', 'orgs/gainpath/members/member');
  });

  it('uses the bound server key for an authorized callable inference', async () => {
    db.getAll.mockResolvedValue([{ data: () => ({ organizationId: 'gainpath' }) }, { data: () => ({ role: 'member', status: 'active', branchIds: [] }) }]);
    const upstream = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify({ detectedEquipment: 'Squat Rack', aliases: [], confidence: 0.99, isGymEquipment: true }) }] } }] }) });
    vi.stubGlobal('fetch', upstream);
    const result = await identifyEquipmentCommand.run({ data: { organizationId: 'gainpath', imageBase64: '/9j/AA==' }, auth: { uid: 'member', token: { email_verified: true } } } as any);
    expect(result).toMatchObject({ detectedEquipment: 'Squat Rack', confidence: 0.99 });
    expect(result).not.toHaveProperty('rawResponse');
    const [url, options] = upstream.mock.calls[0];
    expect(url).toBe('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent');
    expect(url).not.toContain('test-only-key');
    expect(options.headers['x-goog-api-key']).toBe('test-only-key');
  });

  it.each([
    { imageBase64: 'AAECAw==' },
    { imageBase64: 'not base64' },
    { imageBase64: '/9j/AA==', mimeType: 4 },
    { imageBase64: '/9j/AA==', mimeType: 'text/plain' },
    { imageBase64: 'A'.repeat(6 * 1024 * 1024 + 4) },
  ])('rejects invalid image input %# before inference', async data => {
    const upstream = vi.fn();
    await expect(identifyEquipmentWithGemini(data, 'test-only-key', upstream)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(upstream).not.toHaveBeenCalled();
  });

  it.each([
    { detectedEquipment: 'Squat Rack', aliases: [], confidence: 2, isGymEquipment: true },
    { detectedEquipment: 'Squat Rack', aliases: [], confidence: 0.99 },
    { detectedEquipment: 'Squat Rack', aliases: 'rack', confidence: 0.99, isGymEquipment: true },
    null,
  ])('rejects malformed model predictions %#', async prediction => {
    const upstream = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify(prediction) }] } }] }) });
    await expect(identifyEquipmentWithGemini({ imageBase64: '/9j/AA==' }, 'test-only-key', upstream)).rejects.toMatchObject({ code: 'unavailable' });
  });

  it('never returns upstream error details or keys', async () => {
    const fetchFn = vi.fn().mockRejectedValue(new Error('sensitive-test-key'));
    await expect(identifyEquipmentWithGemini({ imageBase64: '/9j/AA==' }, 'sensitive-test-key', fetchFn)).rejects.toMatchObject({ message: 'Equipment recognition is unavailable. Please retry.' });
  });
  it('throws invalid-argument if data is missing or empty', async () => {
    await expect(identifyEquipmentWithGemini(null)).rejects.toThrow(HttpsError);
    await expect(identifyEquipmentWithGemini({})).rejects.toThrow(HttpsError);
    await expect(identifyEquipmentWithGemini({ imageBase64: '   ' })).rejects.toThrow(HttpsError);
  });

  it('throws failed-precondition if GEMINI_API_KEY is not configured', async () => {
    const originalEnv = process.env.GEMINI_API_KEY;
    delete process.env.GEMINI_API_KEY;

    try {
      await expect(
        identifyEquipmentWithGemini({ imageBase64: '/9j/AA==' }, '')
      ).rejects.toThrow(HttpsError);
    } finally {
      process.env.GEMINI_API_KEY = originalEnv;
    }
  });

  it('successfully parses Gemini Vision response', async () => {
    const mockGeminiResponse = {
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  detectedEquipment: 'Squat Rack',
                  aliases: ['Power Rack', 'Squat Stand'],
                  category: 'Compound Lower-Body',
                  confidence: 0.96,
                  isGymEquipment: true,
                }),
              },
            ],
          },
        },
      ],
    };

    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => mockGeminiResponse,
    });

    const result = await identifyEquipmentWithGemini(
      { imageBase64: '/9j/AA==', mimeType: 'image/jpeg' },
      'test-api-key',
      mockFetch as unknown as typeof fetch
    );

    expect(result.detectedEquipment).toBe('Squat Rack');
    expect(result.aliases).toEqual(['Power Rack', 'Squat Stand']);
    expect(result.category).toBe('Compound Lower-Body');
    expect(result.confidence).toBe(0.96);
    expect(result.isGymEquipment).toBe(true);
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  it('sanitizes a model HTTP failure', async () => {
    const mockGeminiResponse = {
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  detectedEquipment: 'Adjustable Bench',
                  aliases: ['Incline Bench'],
                  category: 'Isolation Upper-Body',
                  confidence: 0.91,
                  isGymEquipment: true,
                }),
              },
            ],
          },
        },
      ],
    };

    let callCount = 0;
    const mockFetch = vi.fn().mockImplementation(async () => {
      callCount++;
      if (callCount === 1) {
        return {
          ok: false,
          status: 404,
          text: async () => 'Model not found',
        };
      }
      return {
        ok: true,
        json: async () => mockGeminiResponse,
      };
    });

    await expect(identifyEquipmentWithGemini(
      { imageBase64: '/9j/AA==' }, 'test-api-key', mockFetch as unknown as typeof fetch
    )).rejects.toMatchObject({ code: 'unavailable' });
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });
});
