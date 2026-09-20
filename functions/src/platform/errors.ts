export type ErrorCode = 'invalid-argument' | 'unauthenticated' | 'permission-denied' | 'not-found'
  | 'already-exists' | 'aborted' | 'failed-precondition' | 'resource-exhausted' | 'unavailable';
export class DomainError extends Error {
  constructor(readonly code: ErrorCode, message: string) { super(message); this.name = 'DomainError'; }
}
