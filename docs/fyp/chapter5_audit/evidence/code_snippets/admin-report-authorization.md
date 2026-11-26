# authorizeAdminReport

Source functions/src/modules/analytics/admin-reporting.ts:27–37. Contiguous excerpt. Surrounding code omitted.

```ts
async function authorize(tx:TransactionPort,auth:NonNullable<Auth>,org:string) {
 const [user,member,organization]=await readAll(tx,[`users/${auth.uid}`,`orgs/${org}/members/${auth.uid}`,`orgs/${org}`]);
 if(user?.organizationId!==org||member?.organizationId!==org||requireActiveMembership(member).role!=='admin'||
    (user.role!==undefined&&user.role!=='admin')||(member.userId!==undefined&&member.userId!==auth.uid)||organization?.status!=='active')
   throw new DomainError('permission-denied','Active canonical Admin access is required.');
 if(user.accountLifecycle!==undefined){const l=user.accountLifecycle as DocumentData;
   if(!l||l.schemaVersion!==1||l.state!=='active'||l.revocationPending!==false||!integer(l.sessionNotBeforeSeconds)||
     !integer(auth.token.auth_time)||auth.token.auth_time<l.sessionNotBeforeSeconds)throw new DomainError('permission-denied','Your account session changed.');}
}
// Shared canonical authority guard; neither report grants client backup access.
export {authorize as authorizeAdminReport};
```

Requires canonical association, active Admin and organization, and a current authentication epoch.
