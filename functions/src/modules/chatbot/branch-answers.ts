import type { Firestore } from 'firebase-admin/firestore';

type EquipmentQuestion = { equipment: string; allBranches: boolean };
export type BranchQuestion = 'nearby' | 'current' | 'home' | 'directory' | 'details' | 'hours' | 'directions' | 'facilities' | EquipmentQuestion;

export async function findGym(db: Firestore, org: string, name: string) {
  const rows = await db.collection(`orgs/${org}/branches`).where('status', '==', 'active').limit(31).get();
  const normalized = name.trim().toLowerCase().replace(/\s+/g, ' ');
  const matches = rows.docs.filter(row => {
    const label = row.get('displayName');
    return typeof label === 'string' && label.trim().toLowerCase().replace(/\s+/g, ' ') === normalized;
  });
  if (matches.length !== 1) return undefined;
  return { id: matches[0].id, branch: matches[0].data(), name: String(matches[0].get('displayName')) };
}

export function branchQuestion(text: string): BranchQuestion | undefined {
  const input = text.trim().toLowerCase().replace(/[?.!]+$/, '');
  if (/^(?:(?:which|what) (?:gym|branch) (?:is|iz) )?(?:nearest|closest)(?: gainpath)?(?: (?:gym|branch))?(?: to me)?$|^(?:find )?gyms? near me$/.test(input)) return 'nearby';
  if (/^(?:which|what) (?:gym|branch) (?:am )?i (?:currently )?using$|^what(?:'s|s| is) my selected (?:gym|branch)$/.test(input)) return 'current';
  if (/^what(?:'s|s| is) my home (?:gym|branch)$/.test(input)) return 'home';
  if (/^what time (?:does )?(it|this (?:branch|gym)|my gym|the selected branch) close$/.test(input)) return 'hours';
  if (/^how (can|do) i get (?:there|to (?:this gym|my gym|this branch))$/.test(input)) return 'directions';
  if (/^what facilities (are available(?: (?:at|in) this (?:gym|branch))?|does this (?:gym|branch) have)$/.test(input)) return 'facilities';
  const localEquipment = /^does (?:it|this branch|this gym|my gym|the selected branch) have (?:an? |any )?([\w -]{1,80})$/.exec(input);
  if (localEquipment) return { equipment: localEquipment[1], allBranches: false };
  const sharedEquipment = /^which (?:branches|gyms) have (?:an? |any )?([\w -]{1,80})$/.exec(input);
  if (sharedEquipment) return { equipment: sharedEquipment[1], allBranches: true };
  return undefined;
}

export async function branchAnswer(db: Firestore, org: string, uid: string,
  intent: BranchQuestion, now: number, onBranch?: (branch: Record<string, unknown>) => void, branchName?: string): Promise<string> {
  if (intent === 'nearby') return 'Open Find a gym and tap Use my location. The app sorts branches by approximate straight-line distance on your device.';
  const root = `orgs/${org}`;
  if (typeof intent === 'object' && intent.allBranches) return equipmentAnswer(db, root, intent.equipment);
  if (intent === 'directory') {
    const rows = await db.collection(`${root}/branches`).where('status', '==', 'active').limit(31).get();
    const names = rows.docs.slice(0, 30).map(row => row.get('displayName')).filter(name => typeof name === 'string');
    return names.length ? `Active GainPath branches: ${names.join(', ')}.${rows.size > 30 ? ' Showing up to 30 branches.' : ''}`
      : 'No active gyms are listed in Find a gym.';
  }
  const selected = branchName ? await findGym(db, org, branchName) : await selectedGym(db, org, uid, intent === 'home');
  if (branchName && !selected) return 'I couldn’t match that name to one active GainPath branch. Which branch do you mean?';
  if (selected) {
    const { id, branch, name } = selected;
    onBranch?.({ branchId: id, displayName: name, ...Object.fromEntries(
      ['address', 'latitude', 'longitude', 'coverUrl', 'openingHours', 'facilities', 'status']
        .filter(key => branch[key] !== undefined).map(key => [key, branch[key]])) });
    if (intent === 'current') return `Your selected gym is ${name}. This is the gym selected in GainPath.`;
    if (intent === 'home') return `Your home branch is ${name}.`;
    if (intent === 'details') return `${name}. ${branch.address || 'No address has been saved.'}${typeof branch.phone === 'string' ? ` Contact: ${branch.phone}.` : ''}`;
    if (typeof intent === 'object') return equipmentAnswer(db, root, intent.equipment, { id, name });
    if (intent === 'facilities') {
      const facilities = Array.isArray(branch.facilities)
        ? branch.facilities.filter((value): value is string => typeof value === 'string' && value.trim().length > 0)
        : [];
      return facilities.length ? `${name} lists these facilities: ${facilities.join(', ')}.`
        : `No facilities are listed for ${name}.`;
    }
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
  }
  return 'Choose an active branch in Find a gym, then ask again.';
}

export async function selectedGym(db: Firestore, org: string, uid: string, homeOnly = false) {
  const user = (await db.doc(`users/${uid}`).get()).data();
  for (const id of new Set([...(homeOnly ? [] : [user?.selectedBranchId]), user?.homeBranchId, user?.primaryBranchId])) {
    if (typeof id !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(id)) continue;
    const branch = (await db.doc(`orgs/${org}/branches/${id}`).get()).data();
    if (branch?.status === 'active' && typeof branch.displayName === 'string') {
      return { id, branch, name: branch.displayName };
    }
  }
  return undefined;
}

function equipmentName(value: string): string {
  return value.toLowerCase().trim().replace(/[\s-]+/g, ' ')
    .replace(/\b(dumbbell|treadmill|machine|barbell|kettlebell)s\b/g, '$1');
}

async function equipmentAnswer(db: Firestore, root: string, equipment: string,
  selected?: { id: string; name: string }): Promise<string> {
  const catalog = await db.collection(`${root}/gymEquipment`).where('isActive', '==', true).limit(201).get();
  if (catalog.size > 200) return 'Open Branch Equipment to check the catalog and inventory.';
  const matches = catalog.docs.filter(row => {
    const name = row.get('name');
    return typeof name === 'string' && equipmentName(name) === equipmentName(equipment);
  });
  if (!matches.length) return `I couldn't find “${equipment}” in the active equipment catalog. Try the name shown in Branch Equipment.`;
  if (matches.length > 1) return `More than one catalog entry matches “${equipment}”. Open Branch Equipment to confirm the item.`;
  const item = matches[0];
  const name = String(item.get('name'));
  const directory = selected ? undefined
    : await db.collection(`${root}/branches`).where('status', '==', 'active').limit(31).get();
  const branches = selected ? [selected] : (directory?.docs ?? []).slice(0, 30).flatMap(row => {
    const displayName = row.get('displayName');
    return typeof displayName === 'string' ? [{ id: row.id, name: displayName }] : [];
  });
  if (!branches.length) return 'No active gyms are listed in Find a gym.';
  const rows = await db.getAll(...branches.map(branch => db.doc(`${root}/branches/${branch.id}/equipmentInventory/${item.id}`)));
  const stock = rows.map((row, index) => {
    const data = row.data();
    const quantity = data?.quantity;
    const maintenance = data?.maintenance;
    if (!data || data.removed === true || typeof quantity !== 'number' || !Number.isSafeInteger(quantity)
      || typeof maintenance !== 'number' || !Number.isSafeInteger(maintenance)
      || maintenance < 0 || quantity < maintenance) return undefined;
    return { branch: branches[index].name, usable: quantity - maintenance, quantity, maintenance };
  });
  if (selected) {
    return stock[0] ? `${selected.name} records ${stock[0].usable} usable ${name} unit(s) out of ${stock[0].quantity} recorded, with ${stock[0].maintenance} under maintenance. Check with gym staff for current occupancy.`
      : `Inventory for ${name} at ${selected.name} is unavailable. Check with gym staff.`;
  }
  const usable = stock.flatMap(row => row && row.usable > 0 ? [`${row.branch} (${row.usable})`] : []);
  const partial = (directory?.size ?? 0) > branches.length ? ' Results cover up to 30 active gyms.' : '';
  return usable.length ? `Recorded usable ${name}: ${usable.join(', ')}.${partial}`
    : `No usable ${name} units were confirmed in the checked inventory.${partial}`;
}
