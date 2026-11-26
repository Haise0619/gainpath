# provisionMemberRegistration

Source functions/src/modules/identity/provision-member-registration.ts:21–37. Contiguous excerpt. Surrounding code omitted.

```ts
export const provisionMemberRegistration = onCall(async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const email = request.auth.token.email;
  if (typeof email !== 'string' || !email) {
    throw new HttpsError('failed-precondition', 'The authenticated account must have an email address.');
  }
  try {
    return await provisionMember(new FirestoreStore(getFirestore()), {
      userId: request.auth.uid,
      email,
      displayName: displayNameFrom(request.data),
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    throw new HttpsError('internal', 'The member account could not be provisioned.');
  }
```

Provisioning trusts Firebase Auth identity and maps domain errors to stable callable errors.
