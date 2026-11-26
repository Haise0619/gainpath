import { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { currentBookingMembership, requireBookingOrganization } from '../coaching/booking-validation';

const kinds = ['terms', 'privacy', 'health'] as const;
type Kind = typeof kinds[number];
type Auth = { uid: string; token: Record<string, unknown> } | undefined;
const invalid = (message: string) => new DomainError('invalid-argument', message);
const stale = () => new DomainError('aborted', 'The document changed. Reload and review the latest text.');
const denied = () => new DomainError('permission-denied', 'This compliance action is unavailable.');
const isKind = (value: unknown): value is Kind => kinds.some(kind => kind === value);
const safeId = (value: unknown): value is string =>
  typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);

export async function manageCompliance(store: DocumentStore, auth: Auth,
    input: DocumentData, clock = Date.now) {
  requireVerifiedEmail(auth);
  if (!input || input.schemaVersion !== 1 || !safeId(input.organizationId) || !safeId(auth?.uid)) {
    throw invalid('Invalid compliance request.');
  }
  const org = input.organizationId, uid = auth.uid, root = 'orgs/' + org;
  const doc = (kind: Kind) => root + '/legalDocuments/' + kind;
  const consent = (kind: Kind) => root + '/members/' + uid + '/legalConsents/' + kind;
  const action = input.action;

  return store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, uid);
    await requireBookingOrganization(tx, org);
    if (action === 'memberOverview' || action === 'accept') {
      if (actor.role !== 'member') throw denied();
      if (action === 'memberOverview') {
        const documents = [];
        for (const kind of kinds) {
          const state = await tx.get(doc(kind));
          if (!state?.publication) continue;
          const publication = state.publication as DocumentData;
          const accepted = await tx.get(consent(kind));
          documents.push({
            kind, text: publication.text, version: publication.version,
            revision: publication.revision, publishedAtMillis: publication.publishedAtMillis,
            acceptedVersion: accepted?.version ?? null,
            acceptedAtMillis: accepted?.acceptedAtMillis ?? null,
            requiresConsent: !accepted || Number(accepted.revision) < Number(publication.requiredRevision),
          });
        }
        return { documents };
      }
      if (input.agreed !== true || !Array.isArray(input.documents) || !input.documents.length || input.documents.length > kinds.length) {
        throw invalid('Select the documents you agree to.');
      }
      const acceptedKinds = new Set<Kind>();
      const changes = [];
      for (const selection of input.documents) {
        if (!isKind(selection?.kind) || !Number.isSafeInteger(selection.revision) ||
            acceptedKinds.has(selection.kind)) throw invalid('Invalid document selection.');
        const kind = selection.kind;
        acceptedKinds.add(kind);
        const state = await tx.get(doc(kind));
        const publication = state?.publication as DocumentData | undefined;
        if (!publication || publication.revision !== selection.revision) throw stale();
        const latest = await tx.get(consent(kind));
        if (latest?.revision === publication.revision) continue;
        const receipt = {
          uid, organizationId: org, kind, revision: publication.revision,
          version: publication.version, acceptedAtMillis: clock(),
        };
        changes.push({ kind, receipt });
      }
      for (const { kind, receipt } of changes) {
        tx.create(consent(kind) + '/versions/' + receipt.revision, receipt);
        tx.set(consent(kind), receipt);
      }
      return { saved: true };
    }

    if (actor.role !== 'admin') throw denied();
    if (!isKind(input.kind)) throw invalid('Select a compliance document.');
    const kind = input.kind, path = doc(kind);
    const current = await tx.get(path) ?? {};
    const draft = current.draft as DocumentData | undefined;
    const publication = current.publication as DocumentData | undefined;
    if (action === 'adminOverview') {
      const history = [], draftHistory = [];
      for (let offset = 0; offset < 20; offset++) {
        const revision = Number(publication?.revision ?? 0) - offset;
        if (revision <= 0) break;
        const saved = await tx.get(path + '/versions/' + revision);
        if (saved) history.push(saved);
      }
      for (let offset = 0; offset < 20; offset++) {
        const revision = Number(draft?.revision ?? 0) - offset;
        if (revision <= 0) break;
        const saved = await tx.get(path + '/drafts/' + revision);
        if (saved) draftHistory.push(saved);
      }
      return { draft: draft ?? null, publication: publication ?? null, history, draftHistory };
    }
    if (action === 'saveDraft') {
      if (input.baseRevision !== (draft?.revision ?? 0)) throw stale();
      if (typeof input.text !== 'string' || !input.text.trim() ||
          [...input.text.trim()].length > 12000 || typeof input.isArchived !== 'boolean' ||
          (!draft && input.isArchived)) throw invalid('Enter 1–12000 characters of policy text.');
      const next = {
        text: input.text.trim(), isArchived: input.isArchived,
        revision: Number(draft?.revision ?? 0) + 1, updatedAtMillis: clock(), updatedBy: uid,
      };
      tx.create(path + '/drafts/' + next.revision, next);
      tx.set(path, { ...current, draft: next });
      return { saved: true };
    }
    if (action !== 'publish' || typeof input.requireConsent !== 'boolean') throw invalid('Invalid publication request.');
    if (!draft || draft.isArchived || input.baseRevision !== draft.revision) throw stale();
    if (publication?.draftRevision === draft.revision || publication?.text === draft.text) {
      throw new DomainError('failed-precondition', 'Save a revised draft before publishing again.');
    }
    const requireConsent = !publication || input.requireConsent;
    const revision = Number(publication?.revision ?? 0) + 1;
    const major = requireConsent ? Number(publication?.major ?? 0) + 1 : Number(publication!.major);
    const minor = requireConsent ? 0 : Number(publication!.minor) + 1;
    const next = {
      text: draft.text, revision, draftRevision: draft.revision, version: 'v' + major + '.' + minor,
      major, minor, requireConsent, requiredRevision: requireConsent ? revision : publication!.requiredRevision,
      publishedAtMillis: clock(), publishedBy: uid,
    };
    tx.create(path + '/versions/' + revision, next);
    tx.set(path, { ...current, publication: next });
    return { version: next.version };
  });
}
