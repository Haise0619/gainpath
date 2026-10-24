import { HttpsError, onCall, type CallableRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { getFirestore } from 'firebase-admin/firestore';
import { requireActiveMembership, requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';

const geminiApiKey = defineSecret('GEMINI_API_KEY');

export interface IdentifyEquipmentInput {
  imageBase64: string;
  mimeType?: string;
}

export interface IdentifyEquipmentOutput {
  detectedEquipment: string;
  aliases: string[];
  category?: string;
  confidence: number;
  isGymEquipment: boolean;
  rawResponse?: string;
}

const PROMPT_TEXT = `You are a gym equipment recognition model. Analyze the provided image and identify the gym fitness equipment shown.
Return a JSON object with:
- "detectedEquipment": string (the standard name of the equipment, e.g. "Squat Rack", "Standing Press Station", "Adjustable Bench", "Dumbbell Rack", "Cable Crossover Machine", "Treadmill", "Leg Press Machine", "Smith Machine", "Lat Pulldown Machine", etc.)
- "aliases": array of strings (other common names for this equipment, e.g. ["Power Rack", "Squat Stand"])
- "category": string (e.g. "Compound Lower-Body", "Compound Upper-Body", "Isolation Upper-Body", "Cable & Machine", "Cardio")
- "confidence": number between 0.0 and 1.0 indicating classification confidence
- "isGymEquipment": boolean (true if gym fitness equipment is clearly visible, false if no gym equipment is visible, or the image is unrelated, dark, blurry, or unrecognizable)
Return ONLY the JSON object.`;

export async function identifyEquipmentWithGemini(
  data: unknown,
  apiKeyOverride?: string,
  fetchFn: typeof fetch = fetch
): Promise<IdentifyEquipmentOutput> {
  if (!data || typeof data !== 'object') {
    throw new HttpsError('invalid-argument', 'Image data is required.');
  }

  const { imageBase64, mimeType = 'image/jpeg' } = data as IdentifyEquipmentInput;

  if (!imageBase64 || typeof imageBase64 !== 'string' || imageBase64.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Valid imageBase64 string is required.');
  }

  const apiKey = apiKeyOverride;
  if (!apiKey || apiKey.trim().length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'Gemini API key is not configured on the server. Set GEMINI_API_KEY.'
    );
  }

  const cleanBase64 = imageBase64.trim();
  if (typeof mimeType !== 'string' || !['image/jpeg', 'image/png'].includes(mimeType) ||
      cleanBase64.length > 6 * 1024 * 1024 ||
      !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(cleanBase64)) {
    throw new HttpsError('invalid-argument', 'A JPEG or PNG image up to 4.5 MiB is required.');
  }
  const bytes = Buffer.from(cleanBase64, 'base64');
  const jpeg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const png = bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  if ((mimeType === 'image/jpeg' && !jpeg) || (mimeType === 'image/png' && !png)) {
    throw new HttpsError('invalid-argument', 'Image format does not match its content.');
  }

  const models = ['gemini-3.5-flash-lite'];

  for (const model of models) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
      const payload = {
        contents: [
          {
            parts: [
              { text: PROMPT_TEXT },
              {
                inlineData: {
                  mimeType: mimeType.trim() || 'image/jpeg',
                  data: cleanBase64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: 'application/json',
          temperature: 0.1,
        },
      };

      const response = await fetchFn(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey.trim() },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(20000),
      });

      if (!response.ok) {
        throw new Error('Vision service rejected the request.');
      }

      const jsonResponse = (await response.json()) as any;
      const text =
        jsonResponse?.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!text || typeof text !== 'string') {
        throw new Error('Gemini response did not contain text content.');
      }

      const parsed = JSON.parse(text.trim());
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed) ||
          typeof parsed.detectedEquipment !== 'string' || parsed.detectedEquipment.length > 160 ||
          typeof parsed.isGymEquipment !== 'boolean' ||
          typeof parsed.confidence !== 'number' || !Number.isFinite(parsed.confidence) ||
          parsed.confidence < 0 || parsed.confidence > 1 ||
          !Array.isArray(parsed.aliases) || parsed.aliases.length > 20 ||
          !parsed.aliases.every((a: unknown) => typeof a === 'string' && a.length <= 160)) {
        throw new Error('Invalid vision prediction.');
      }
      const detected = typeof parsed.detectedEquipment === 'string' ? parsed.detectedEquipment.trim() : '';
      const aliases = Array.isArray(parsed.aliases)
        ? parsed.aliases.filter((a: unknown) => typeof a === 'string' && (a as string).trim().length > 0)
        : [];
      const confidence = typeof parsed.confidence === 'number' ? parsed.confidence : 0.0;
      const isGymEquipment = typeof parsed.isGymEquipment === 'boolean' ? parsed.isGymEquipment : detected.length > 0;
      const category = typeof parsed.category === 'string' ? parsed.category.trim() : undefined;

      return {
        detectedEquipment: detected,
        aliases,
        category,
        confidence,
        isGymEquipment,
      };
    } catch (_) {
      continue;
    }
  }

  throw new HttpsError(
    'unavailable',
    'Equipment recognition is unavailable. Please retry.'
  );
}

export const identifyEquipmentCommand = onCall(
  { timeoutSeconds: 30, secrets: [geminiApiKey], enforceAppCheck: true },
  async (request: CallableRequest) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be signed in to scan equipment.');
    }
    try {
      requireVerifiedEmail(request.auth);
      const org = request.data?.organizationId;
      if (typeof org !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(org)) {
        throw new HttpsError('invalid-argument', 'A valid organizationId is required.');
      }
      const db = getFirestore();
      const [user, member] = await db.getAll(db.doc(`users/${request.auth.uid}`), db.doc(`orgs/${org}/members/${request.auth.uid}`));
      if (user.data()?.organizationId !== org || requireActiveMembership(member.data()).role !== 'member') {
        throw new HttpsError('permission-denied', 'An active member of this organization is required.');
      }
      return await identifyEquipmentWithGemini(request.data, geminiApiKey.value());
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
      throw new HttpsError('unavailable', 'Equipment recognition is unavailable. Please retry.');
    }
  }
);
