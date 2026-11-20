import { FieldPath, Firestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

function branchId(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

export async function readMemberAnnouncements(
  db: Firestore, org: string, uid: string, afterId?: string, now = Timestamp.now(),
) {
  const root = db.collection('orgs').doc(org);
  return db.runTransaction(async tx => {
    const [user, member] = await tx.getAll(
      db.collection('users').doc(uid), root.collection('members').doc(uid),
    );
    if (user.get('organizationId') !== org || member.get('organizationId') !== org ||
        member.get('status') !== 'active') {
      throw new HttpsError('permission-denied', 'Announcement access is unavailable.');
    }
    const home = user.get('homeBranchId') ?? user.get('primaryBranchId');
    const selected = user.get('selectedBranchId');
    const candidates = [...new Set([home, selected].filter(branchId))];
    const branches = candidates.length
      ? await tx.getAll(...candidates.map(id => root.collection('branches').doc(id)))
      : [];
    const matches = new Set(branches
      .filter(branch => branch.exists && (branch.id === home || branch.get('status') === 'active'))
      .map(branch => branch.id));

    let query = root.collection('announcements').where('status', '==', 'published')
      .orderBy(FieldPath.documentId()).limit(50);
    if (afterId) query = query.startAfter(afterId);
    const page = await tx.get(query);
    const visible = page.docs.filter(doc => {
      const from = doc.get('validFrom');
      const to = doc.get('validTo');
      if (doc.get('schemaVersion') !== 1 || !(from instanceof Timestamp) ||
          !(to instanceof Timestamp) || from.valueOf() > now.valueOf() ||
          to.valueOf() <= now.valueOf()) return false;
      const scope = doc.get('audienceScope');
      const targets = doc.get('targetBranchIds');
      if (scope === undefined || scope === 'all') return true;
      return scope === 'branches' && Array.isArray(targets) &&
        targets.some(id => matches.has(id));
    });
    const ids = new Set<string>();
    for (const doc of visible) {
      const targets = doc.get('targetBranchIds');
      if (doc.get('audienceScope') === 'branches' && Array.isArray(targets)) {
        for (const target of targets) if (branchId(target)) ids.add(target);
      }
    }
    const directory = ids.size
      ? await tx.getAll(...[...ids].map(id => root.collection('branches').doc(id)))
      : [];
    const names = new Map(directory.map(branch => [branch.id, branch.get('displayName')]));
    return {
      records: visible.map(doc => ({
        id: doc.id, title: doc.get('title'), body: doc.get('body'),
        revision: doc.get('revision'), category: doc.get('category') ?? 'general',
        priority: doc.get('priority') ?? 'normal',
        audienceScope: doc.get('audienceScope') ?? 'all',
        targetBranchIds: doc.get('audienceScope') === 'branches' ? doc.get('targetBranchIds') : [],
        branchNames: (Array.isArray(doc.get('targetBranchIds')) ? doc.get('targetBranchIds') : [])
          .map((id: string) => names.get(id)).filter((name: unknown) => typeof name === 'string'),
        validFromMillis: Math.trunc((doc.get('validFrom') as Timestamp).toMillis()),
        validToMillis: Math.trunc((doc.get('validTo') as Timestamp).toMillis()),
      })),
      ...(page.size === 50 ? { nextAfterId: page.docs[49].id } : {}),
    };
  }, { readOnly: true });
}
