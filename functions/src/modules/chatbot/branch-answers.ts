import type { Firestore } from 'firebase-admin/firestore';

export function branchQuestion(text: string): 'nearby' | 'hours' | 'directions' | 'treadmill' | undefined {
  const input = text.trim().toLowerCase().replace(/[?.!]+$/, '');
  if (/^(which|what) gym is (nearest|closest) to me$/.test(input)) return 'nearby';
  if (/^what time does (this branch|my gym|the selected branch) close$/.test(input)) return 'hours';
  if (/^how (can|do) i get to (this gym|my gym|this branch)$/.test(input)) return 'directions';
  if (/^does (this branch|my gym|the selected branch) have a treadmill$/.test(input)) return 'treadmill';
  return undefined;
}

export async function branchAnswer(db: Firestore, org: string, uid: string,
  intent: NonNullable<ReturnType<typeof branchQuestion>>, now: number): Promise<string> {
  if (intent === 'nearby') return 'Open Find a gym and tap Use my location. The app sorts branches by approximate straight-line distance on your device.';
  const root = `orgs/${org}`;
  const user = (await db.doc(`users/${uid}`).get()).data();
  for (const id of new Set([user?.selectedBranchId, user?.homeBranchId, user?.primaryBranchId])) {
    if (typeof id !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(id)) continue;
    const branch = (await db.doc(`${root}/branches/${id}`).get()).data();
    if (branch?.status !== 'active' || typeof branch.displayName !== 'string') continue;
    const name = branch.displayName;
    if (intent === 'directions') return `Open Find a gym → ${name} → Get directions. ${typeof branch.address === 'string' && branch.address ? `Saved address: ${branch.address}.` : 'The address has not been recorded.'}`;
    if (intent === 'hours') {
      const local = new Date(now + 8 * 3600000);
      const day = Array.isArray(branch.openingHours) ? branch.openingHours[(local.getUTCDay() + 6) % 7] : undefined;
      if (!day) return `Opening hours are not available for ${name}.`;
      if (day.closed === true) return `${name} is scheduled to be closed today (MYT).`;
      if (day.allDay === true) return `${name} is scheduled to be open 24 hours today (MYT).`;
      if (typeof day.open === 'string' && typeof day.close === 'string') {
        return `${name} is scheduled for ${day.open}–${day.close} MYT${day.close < day.open ? ' (closes the following day)' : ''}.`;
      }
      return `Opening hours are not available for ${name}.`;
    }
    const rows = await db.collection(`${root}/branches/${id}/equipmentInventory`).limit(101).get();
    const matching = rows.docs.map(row => row.data()).filter(row =>
      row.removed !== true && typeof row.name === 'string' && /\btreadmills?\b/i.test(row.name));
    if (!matching.length) return `No treadmill is listed in the checked inventory for ${name}. Confirm with branch staff if needed.`;
    if (rows.size > 100) return `A treadmill is listed at ${name}. Open the Equipment list for the recorded quantities.`;
    const usable = matching.reduce((sum, item) => sum + (Number(item.quantity) - Number(item.maintenance)), 0);
    return `${name} records ${usable} usable treadmill unit(s). This does not indicate whether a machine is occupied right now.`;
  }
  return 'Choose an active branch in Find a gym, then ask again.';
}
