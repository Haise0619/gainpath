/** Bounded direct-media contract. Availability/licensing is a separate review. */
export function tutorialMediaUrl(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const text = value.trim();
  if (!text || text.length > 2048 || !/^https:\/\/[^/]/i.test(text)
    || /[\x00-\x20\x7f\\#]/.test(text)) return undefined;
  try {
    const uri = new URL(text);
    if (uri.protocol !== 'https:' || !/^[a-z0-9.-]+$/i.test(uri.hostname) || uri.username || uri.password
      || uri.hash || !uri.pathname.toLowerCase().endsWith('.mp4')) return undefined;
    return text;
  } catch { return undefined; }
}
