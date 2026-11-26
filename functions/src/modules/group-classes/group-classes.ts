import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { DocumentData, TransactionPort } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { requiredIdentifier } from '../../platform/validation';
import { bookingCoachScope, bookingDaySnapshot, currentBookingMembership, currentBookingPolicy, requireBookingOrganization } from '../coaching/booking-validation';
import { localDate, SLOT } from '../coaching/coach-availability-contracts';
import { resolveMembershipEntitlement } from '../commerce/membership-entitlement';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
export interface ClassTransaction extends TransactionPort {
  list(path: string): Promise<{ id: string; data: DocumentData }[]>;
  remove(path: string): void;
}
export type ClassStore = { transact<T>(work: (tx: ClassTransaction) => Promise<T>): Promise<T> };
export const categories = ['Yoga', 'HIIT', 'Strength', 'Dance', 'Pilates', 'Other'];
const eligibility = ['All Members', 'Paid Members', 'Premium Only'];
const classEligibility = (value: unknown) =>
  value === 'Premium Only' ? 'Premium Only' : 'Paid Members';
const invalid = (message: string) => new DomainError('invalid-argument', message);
const blocked = (message: string) => new DomainError('failed-precondition', message);
const denied = () => new DomainError('permission-denied', 'Group class access is unavailable.');
const parseText = (value: unknown, max: number, optional = false) => {
  if (optional && (value === '' || value == null)) return '';
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) throw invalid('Check the class form fields.');
  return value.trim();
};
const millis = (value: unknown) => {
  if (!Number.isSafeInteger(value) || Number(value) < 1 || Number(value) > 253402300799999) throw invalid('Enter valid dates and times.');
  return Number(value);
};
const overlaps = (a: DocumentData, b: DocumentData) =>
  Number(a.startAtMillis) < Number(b.endAtMillis) && Number(b.startAtMillis) < Number(a.endAtMillis);
const slotKeys = (row: DocumentData) => {
  const keys: number[] = [];
  for (let at = Number(row.startAtMillis); at < Number(row.endAtMillis); at += SLOT) keys.push(at);
  return keys;
};
export function classStatus(row: DocumentData, now: number) {
  if (row.state === 'Draft' || row.state === 'Cancelled') return row.state;
  if (Number(row.endAtMillis) <= now) return 'Completed';
  if (Number(row.startAtMillis) <= now) return 'In progress';
  if (row.state === 'Closed' || Number(row.closeAtMillis) <= now) return 'Closed';
  if (Number(row.openAtMillis) > now) return 'Scheduled';
  return Number(row.activeCount) >= Number(row.capacity) ? 'Full' : 'Open';
}
const projection = (id: string, row: DocumentData, now: number) =>
  ({ ...row, id, eligibility: classEligibility(row.eligibility), status: classStatus(row, now) });

async function canJoinClass(tx: ClassTransaction, auth: Auth, org: string, row: DocumentData) {
  const tier = await resolveMembershipEntitlement(tx, auth, org, Number(row.startAtMillis));
  return tier.paidStatus === 'active' &&
      (classEligibility(row.eligibility) !== 'Premium Only' || tier.effectiveTier === 'premium');
}

export async function groupClasses(store: ClassStore, auth: Auth, input: DocumentData, clock = Date.now) {
  requireVerifiedEmail(auth);
  if (input?.schemaVersion !== 1) throw invalid('Unsupported class request.');
  const org = requiredIdentifier(input.organizationId, 'organizationId');
  const uid = requiredIdentifier(auth!.uid, 'uid');
  const root = 'orgs/' + org, classes = root + '/groupClasses', now = clock();
  const classPath = (id: string) => classes + '/' + id;
  const schedulePath = (member: string) => root + '/groupClassSchedules/' + member;
  const lockPath = (coach: unknown, at: number) => root + '/slotLocks/' + keyOf(coach, at);
  const lockId = (id: string) => 'class-' + id;
  const action = input.action;

  return store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, uid);
    await requireBookingOrganization(tx, org);
    const admin = actor.role === 'admin';
    if (!admin && actor.role !== 'member') throw denied();
    const notify = (member: string, id: string, title: string, message: string) => {
      tx.create(root + '/notifications/' + keyOf('group-class', uid, input.requestId, id, member), {
        schemaVersion: 1, type: 'group_class', recipientId: member,
        title, message, groupClassId: id, createdAtMillis: now, read: false,
      });
    };
    const schedule = async (member: string) => {
      const row = await tx.get(schedulePath(member));
      return ((row?.active ?? []) as DocumentData[]).filter(item => Number(item.endAtMillis) > now);
    };

    if (action === 'options') {
      if (!admin) throw denied();
      const [branches, coaches] = await Promise.all([
        tx.list(root + '/branches'), tx.list(root + '/coaches'),
      ]);
      return {
        branches: branches.filter(x => x.data.status === 'active')
            .map(x => ({ id: x.id, name: x.data.displayName ?? x.id })),
        coaches: coaches.filter(x => x.data.status === 'published')
            .map(x => ({ id: x.id, name: x.data.displayName ?? x.id, specialty: x.data.specialty ?? '', photoUrl: x.data.photoUrl ?? null })),
      };
    }
    if (action === 'list' || action === 'calendar' || action === 'analytics') {
      if (action !== 'list' && !admin) throw denied();
      const index = admin ? undefined : await tx.get(schedulePath(uid));
      const registrations = (index?.registrations ?? {}) as DocumentData;
      const rows = (await tx.list(classes))
        .filter(({ id, data }) => admin || (data.state !== 'Draft' &&
            (registrations[id] != null || Number(data.endAtMillis) > now)))
        .filter(({ data }) => input.branchId == null || data.branchId === input.branchId);
      if (action === 'analytics') {
        const range = rows.filter(({ data }) => data.state !== 'Draft' &&
            (input.startAtMillis == null || Number(data.startAtMillis) >= millis(input.startAtMillis)) &&
            (input.endAtMillis == null || Number(data.startAtMillis) < millis(input.endAtMillis)));
        return { classes: range.map(({ id, data }) => projection(id, data, now)) };
      }
      const selected = action === 'calendar' ? rows.filter(({ data }) => data.state !== 'Draft' &&
          Number(data.startAtMillis) < millis(input.endAtMillis) && Number(data.endAtMillis) > millis(input.startAtMillis)) : rows;
      return {
        classes: selected.map(({ id, data }) => ({
          ...projection(id, data, now),
          registration: registrations[id] ?? null,
        })),
        serverNowMillis: now,
      };
    }

    const id = requiredIdentifier(input.id, 'classId'), path = classPath(id);
    const prior = await tx.get(path);
    if (!prior && action !== 'save') throw new DomainError('not-found', 'Class unavailable.');
    if (!admin && prior?.state === 'Draft') throw denied();
    const participantsPath = path + '/participants';
    if (action === 'detail') {
      const registration = admin ? null : await tx.get(participantsPath + '/' + uid);
      const participants = admin ? await tx.list(participantsPath) : [];
      const eligible = admin || await canJoinClass(tx, auth, org, prior!);
      return { item: { ...projection(id, prior!, now), registration, eligible },
        participants: participants.map(item => ({ memberId: item.id, ...item.data })), serverNowMillis: now };
    }

    const requestId = requiredIdentifier(input.requestId, 'requestId');
    const receipt = root + '/groupClassCommands/' + keyOf(uid, requestId);
    const fingerprint = keyOf(input);
    const seen = await tx.get(receipt);
    if (seen) {
      if (seen.fingerprint !== fingerprint) throw invalid('This request ID already belongs to another action.');
      return { saved: true, id };
    }
    const finish = () => {
      tx.create(receipt, { fingerprint, uid, atMillis: now });
      return { saved: true, id };
    };
    if (action === 'join' || action === 'leave' || action === 'removeParticipant') {
      if (action === 'removeParticipant' ? !admin : admin) throw denied();
      const member = admin ? requiredIdentifier(input.memberId, 'memberId') : uid;
      const p = participantsPath + '/' + member;
      const registration = await tx.get(p);
      const current = prior!;
      const attending = registration?.status === 'Registered';
      const index = await tx.get(schedulePath(member));
      const active = await schedule(member);
      const registrations = { ...((index?.registrations ?? {}) as DocumentData) };
      if (action !== 'join') {
        if (!attending) throw blocked('No active registration to cancel.');
        if (current.state === 'Cancelled' || (!admin && now > Number(current.startAtMillis) - 7200000) ||
            now >= Number(current.endAtMillis)) throw blocked('Registration can no longer be cancelled.');
        registrations[id] = 'Cancelled';
        tx.set(p, { ...registration, status: 'Cancelled', cancelledAtMillis: now, cancelledBy: uid,
          cancellations: [...((registration?.cancellations ?? []) as DocumentData[]), { atMillis: now, by: uid }] });
        tx.set(schedulePath(member), { active: active.filter(item => item.id !== id), registrations });
        tx.set(path, { ...current, activeCount: Number(current.activeCount) - 1, cancellationCount: Number(current.cancellationCount) + 1 });
        notify(member, id, 'Class registration cancelled', String(current.title));
        return finish();
      }
      if (attending) throw blocked('You are already registered for this class.');
      if (classStatus(current, now) !== 'Open') throw blocked('Registration is closed or the class is full.');
      if (active.some(item => item.id !== id && overlaps(item, current))) throw blocked('This class overlaps another registration.');
      if (!(await canJoinClass(tx, auth, org, current))) {
        throw blocked('An eligible paid membership is required on the class date.');
      }
      const details = await tx.get(root + '/members/' + member);
      registrations[id] = 'Registered';
      tx.set(p, { status: 'Registered', name: details?.displayName ?? member, registeredAtMillis: now,
        cancellations: registration?.cancellations ?? [] });
      tx.set(schedulePath(member), { registrations, active: [...active, {
        id, startAtMillis: current.startAtMillis, endAtMillis: current.endAtMillis,
      }] });
      tx.set(path, { ...current, activeCount: Number(current.activeCount) + 1, totalRegistrations: Number(current.totalRegistrations) + 1 });
      notify(member, id, 'Class registration confirmed', String(current.title));
      return finish();
    }

    if (!admin) throw denied();
    if (action === 'attendance') {
      if (classStatus(prior!, now) !== 'Completed') throw blocked('Attendance opens after the class ends.');
      const member = requiredIdentifier(input.memberId, 'memberId');
      const p = participantsPath + '/' + member, registration = await tx.get(p);
      const value = input.status;
      if (!registration || registration.status === 'Cancelled' || !['Attended', 'Absent'].includes(String(value))) throw invalid('Select a registered participant and attendance outcome.');
      const count = (field: string, status: string) => Number(prior![field]) -
          (registration.status === status ? 1 : 0) + (value === status ? 1 : 0);
      const index = await tx.get(schedulePath(member));
      if (index) tx.set(schedulePath(member), { ...index, registrations: { ...index.registrations as DocumentData, [id]: value } });
      tx.set(p, { ...registration, status: value, markedAtMillis: now, markedBy: uid });
      tx.set(path, { ...prior, attendedCount: count('attendedCount', 'Attended'), absentCount: count('absentCount', 'Absent') });
      return finish();
    }

    if (prior && (prior.state === 'Cancelled' || (prior.state !== 'Draft' && Number(prior.startAtMillis) <= now))) {
      throw blocked('This class can no longer be changed.');
    }
    if (action === 'close') {
      if (prior!.state !== 'Published') throw blocked('Only a published class can be closed.');
      tx.set(path, { ...prior, state: 'Closed', updatedAtMillis: now });
      return finish();
    }

    if (!['save', 'publish', 'cancel'].includes(String(action))) throw invalid('Unsupported group class action.');
    const next: DocumentData = { ...prior, updatedAtMillis: now };
    if (action === 'save') {
      const data = input.item as DocumentData;
      if (!data || typeof data !== 'object') throw invalid('Enter class details.');
      const start = millis(data.startAtMillis), end = millis(data.endAtMillis);
      const open = millis(data.openAtMillis), close = millis(data.closeAtMillis);
      const capacity = Number(data.capacity), branchId = requiredIdentifier(data.branchId, 'branchId');
      const branch = await tx.get(root + '/branches/' + branchId);
      if (branch?.status !== 'active') throw invalid('Select an active branch.');
      if (start <= now || start % SLOT || end % SLOT || end <= start || end - start > 4 * 3600000 ||
          localDate(start, 'Asia/Kuala_Lumpur') !== localDate(end - 1, 'Asia/Kuala_Lumpur') || open >= close ||
          close > start || !Number.isSafeInteger(capacity) || capacity < Math.max(1, Number(prior?.activeCount ?? 0)) ||
          capacity > 60 || !categories.includes(String(data.category)) || !eligibility.includes(String(data.eligibility)) ||
          !['Beginner', 'Intermediate', 'Advanced', 'All levels'].includes(String(data.difficulty))) {
        throw invalid('Check capacity, registration dates and the 30-minute class time grid.');
      }
      const coachId = data.coachId ? requiredIdentifier(data.coachId, 'coachId') : null;
      const coach = coachId ? await tx.get(root + '/coaches/' + coachId) : null;
      if (coachId && coach?.status !== 'published') throw invalid('Select a published coach.');
      const cover = parseText(data.coverUrl, 1200, true);
      if (cover && (!cover.startsWith('https://firebasestorage.googleapis.com/') ||
          !decodeURIComponent(cover).includes('/o/' + root + '/groupClassImages/'))) throw invalid('Upload the cover image through GainPath.');
      Object.assign(next, {
        title: parseText(data.title, 100), description: parseText(data.description, 2000),
        venue: parseText(data.venue, 100), branchId, branchName: branch.displayName ?? branchId,
        coachId, instructor: coachId ? parseText(coach?.displayName, 100) : parseText(data.instructor, 100),
        specialty: coach?.specialty ?? null, instructorPhoto: coach?.photoUrl ?? null,
        category: data.category, eligibility: classEligibility(data.eligibility), difficulty: data.difficulty,
        coverUrl: cover, startAtMillis: start, endAtMillis: end, openAtMillis: open,
        closeAtMillis: close, capacity, state: prior?.state ?? 'Draft',
        activeCount: prior?.activeCount ?? 0, totalRegistrations: prior?.totalRegistrations ?? 0,
        cancellationCount: prior?.cancellationCount ?? 0, attendedCount: prior?.attendedCount ?? 0, absentCount: prior?.absentCount ?? 0,
      });
    } else if (action === 'publish') {
      if (prior!.state !== 'Draft' || now >= Number(prior!.closeAtMillis)) throw blocked('Save a future draft with an open registration window.');
      const branch = await tx.get(root + '/branches/' + String(prior!.branchId));
      if (branch?.status !== 'active') throw blocked('Select an active branch before publishing.');
      next.state = 'Published';
    } else {
      next.state = 'Cancelled';
    }
    const changed = !!prior && ['startAtMillis', 'endAtMillis', 'branchId', 'venue', 'coachId', 'instructor']
        .some(field => next[field] !== prior[field]);
    if (prior && Number(prior.activeCount) > 0 && (changed || action === 'cancel') && input.confirmChanges !== true) {
      throw blocked('Confirm the change and notify registered members.');
    }

    const participantUpdates: { member: string; active: DocumentData[]; registrations: DocumentData; row: DocumentData }[] = [];
    if (prior && (changed || action === 'cancel') && Number(prior.activeCount) > 0) {
      for (const { id: member, data: row } of await tx.list(participantsPath)) {
        if (row.status !== 'Registered') continue;
        const current = await tx.get(schedulePath(member));
        const active = (await schedule(member)).filter(item => item.id !== id);
        if (action !== 'cancel' && active.some(item => overlaps(item, next))) {
          throw blocked('The new time overlaps a participant’s other class.');
        }
        participantUpdates.push({ member, active, registrations: { ...current?.registrations as DocumentData }, row });
      }
    }

    const oldLocks: string[] = [];
    if (prior?.coachId && prior.state !== 'Draft' && (changed || action === 'cancel')) {
      for (const at of slotKeys(prior)) {
        const lock = lockPath(prior.coachId, at);
        if ((await tx.get(lock))?.bookingId === lockId(id)) oldLocks.push(lock);
      }
    }
    const newLocks: string[] = [];
    if (next.coachId && next.state !== 'Draft' && next.state !== 'Cancelled' &&
        (changed || action === 'publish')) {
      const scoped = await bookingCoachScope(tx, org, String(next.coachId));
      if (!scoped.permitted.includes(String(next.branchId))) throw blocked('Coach is not available at this branch.');
      const policy = currentBookingPolicy(await tx.get(root + '/settings/booking'));
      const day = await bookingDaySnapshot(tx, org, String(next.coachId), uid,
          localDate(Number(next.startAtMillis), policy.timeZone), policy, scoped.assigned, now, lockId(id));
      for (const at of slotKeys(next)) {
        if (day.blocked.has(at)) {
          throw blocked('The selected coach already has a reservation during this class.');
        }
        if (!day.windows.some(window =>
            window.branchId === next.branchId && window.startAtMillis <= at && window.endAtMillis >= at + SLOT)) {
          throw blocked('The coach has no availability at this branch for the full class time.');
        }
        newLocks.push(lockPath(next.coachId, at));
      }
    }

    for (const lock of oldLocks) if (!newLocks.includes(lock)) tx.remove(lock);
    for (const lock of newLocks) tx.set(lock, {
      schemaVersion: 1, bookingId: lockId(id), coachId: next.coachId,
      branchId: next.branchId, status: 'confirmed',
    });
    for (const update of participantUpdates) {
      const cancelled = action === 'cancel';
      if (cancelled) {
        update.registrations[id] = 'Cancelled';
        tx.set(participantsPath + '/' + update.member, {
          ...update.row, status: 'Cancelled', cancelledAtMillis: now, cancelledBy: uid,
          cancellations: [...((update.row.cancellations ?? []) as DocumentData[]), { atMillis: now, by: uid }],
        });
      } else {
        update.active.push({ id, startAtMillis: next.startAtMillis, endAtMillis: next.endAtMillis });
      }
      tx.set(schedulePath(update.member), { active: update.active, registrations: update.registrations });
      notify(update.member, id, cancelled ? 'Group class cancelled' : 'Group class updated',
          String(next.title) + (cancelled ? '' : ' · Check the updated schedule.'));
    }
    if (action === 'cancel') {
      next.cancellationCount = Number(next.cancellationCount) + participantUpdates.length;
      next.activeCount = 0;
    }
    tx.set(path, next);
    return finish();
  });
}
