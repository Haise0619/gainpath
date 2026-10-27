import { DomainError } from '../../platform/errors';

function imageUrl(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const text = value.trim();
  if (!text || text.length > 2048 || !text.startsWith('https://')
    || /[\x00-\x20\x7f\\#]/.test(text)) return undefined;
  try {
    const url = new URL(text);
    return url.protocol === 'https:' && /^[a-zA-Z0-9.-]+$/.test(url.hostname)
      && !url.username && !url.password && !url.hash ? text : undefined;
  } catch { return undefined; }
}

/** Bounded instructions from the exact active catalog record; never AI capability. */
export function exerciseTutorialProjection(source: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, max] of [['description', 2000], ['equipment', 300]] as const) {
    const value = source[key];
    if (value === undefined) continue;
    if (typeof value !== 'string' || value.trim().length > max) {
      throw new DomainError('failed-precondition', 'Exercise tutorial text is invalid.');
    }
    if (value.trim()) result[key] = value.trim();
  }
  if (source.difficulty !== undefined) {
    if (typeof source.difficulty !== 'string'
      || !['Beginner', 'Intermediate', 'Advanced'].includes(source.difficulty)) {
      throw new DomainError('failed-precondition', 'Exercise difficulty is invalid.');
    }
    result.difficulty = source.difficulty;
  }
  const cover = imageUrl(source.coverImageUrl);
  if (cover) { result.coverImageUrl = cover; result.imageUrl = cover; }
  if (source.tutorialSteps !== undefined) {
    if (!Array.isArray(source.tutorialSteps) || source.tutorialSteps.length > 12) {
      throw new DomainError('failed-precondition', 'Exercise tutorial has too many steps.');
    }
    result.tutorialSteps = source.tutorialSteps.map(raw => {
      if (!raw || typeof raw !== 'object' || Array.isArray(raw)
        || Object.keys(raw).some(key => !['title', 'description', 'imageUrl'].includes(key))
        || typeof raw.title !== 'string' || !raw.title.trim() || raw.title.trim().length > 80
        || typeof raw.description !== 'string' || !raw.description.trim() || raw.description.trim().length > 1200) {
        throw new DomainError('failed-precondition', 'An exercise tutorial step is invalid.');
      }
      return { title: raw.title.trim(), description: raw.description.trim(),
        imageUrl: imageUrl(raw.imageUrl) ?? '' };
    });
  }
  return result;
}
