/** Versioned wire envelope; requestId is an opaque client-generated retry key. */
export interface CommandV1 {
  readonly schemaVersion: 1;
  readonly requestId: string;
  readonly organizationId: string;
}
