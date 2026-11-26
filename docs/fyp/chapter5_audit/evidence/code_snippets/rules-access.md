# activeMember and contentAuthor

Source firebase/firestore.rules:5–26. Contiguous excerpt. Surrounding code omitted.

```text
    function signedIn() {
      return request.auth != null;
    }

    function activeMember(orgId) {
      return signedIn()
        && request.auth.token.email_verified == true
        && exists(/databases/$(database)/documents/orgs/$(orgId)/members/$(request.auth.uid))
        && get(/databases/$(database)/documents/orgs/$(orgId)/members/$(request.auth.uid)).data.status == 'active';
    }

    function adminMember(orgId) {
      return activeMember(orgId)
        && get(/databases/$(database)/documents/orgs/$(orgId)/members/$(request.auth.uid)).data.role == 'admin';
    }

    function contentAuthor(orgId) {
      let membership = get(/databases/$(database)/documents/orgs/$(orgId)/members/$(request.auth.uid)).data;
      let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
      return signedIn() && request.auth.token.email_verified == true
        && membership.status == 'active' && user.organizationId == orgId
        && membership.organizationId == orgId && membership.role in ['admin', 'staff'];
```

Rules combine authentication, verified email, canonical membership, and role. Callables maintain their own server-side checks.
