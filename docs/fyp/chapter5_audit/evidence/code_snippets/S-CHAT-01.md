# S-CHAT-01 — fitnessAssistantHandler

Chapter section 5.1.4.8. Source `functions/src/modules/chatbot/chatbot-callable.ts:38–61`. Related regression `functions/test/chatbot-callable.test.ts`.

An authenticated transaction binds the current disclosure notice, rate limit and bounded saved state. Surrounding source omitted.

```ts
    const reauthorize = () => db.runTransaction(async tx => {
      const [user, member, organization] = await tx.getAll(db.doc(`users/${uid}`), db.doc(`orgs/${org}/members/${uid}`), db.doc(`orgs/${org}`));
      requireCanonical(user.data(), member.data(), organization.data());
    });
    const result = await db.runTransaction(async tx => {
      const [user, member, organization, disclaimerDoc, stateDoc] = await tx.getAll(db.doc(`users/${uid}`), db.doc(`orgs/${org}/members/${uid}`), db.doc(`orgs/${org}`), db.doc(`orgs/${org}/chatbotDisclaimer/config`), stateRef);
      const u = user.data(), m = member.data();
      requireCanonical(u, m, organization.data());
      const disclaimer = disclaimerDoc.data();
      if (!disclaimer || disclaimer.isActive !== true || typeof disclaimer.text !== 'string' || !disclaimer.text.trim() || disclaimer.text.length > 10000 || !Number.isSafeInteger(disclaimer.revision) || disclaimer.revision < 1) throw new HttpsError('failed-precondition', 'The organization disclaimer is unavailable.');
      const previous = stateDoc.data() ?? {};
      const state = { schemaVersion: 1, acknowledgedRevision: Number(previous.acknowledgedRevision ?? 0), bookmarks: Array.isArray(previous.bookmarks) ? previous.bookmarks.filter((v: unknown) => typeof v === 'string' && v.length <= 6000).slice(-50) : [], ratings: Array.isArray(previous.ratings) ? previous.ratings.slice(-100) : [], rateWindowMillis: Number(previous.rateWindowMillis ?? 0), rateCount: Number(previous.rateCount ?? 0) };
      if (input.action === 'bootstrap') return { disclaimer: { text: disclaimer.text, revision: disclaimer.revision }, acknowledged: state.acknowledgedRevision === disclaimer.revision, bookmarks: state.bookmarks, contextMode:privateProviderApproved()?'private-approved':'public' };
      if (input.action === 'acknowledge') {
        if (input.disclaimerRevision !== disclaimer.revision) throw new HttpsError('failed-precondition', 'Please review the current disclaimer.');
        state.acknowledgedRevision = disclaimer.revision;
      } else {
        if (state.acknowledgedRevision !== disclaimer.revision) throw new HttpsError('failed-precondition', 'Acknowledge the current disclaimer first.');
        if (input.action === 'reply') {
          if (now - state.rateWindowMillis >= 60000) { state.rateWindowMillis = now; state.rateCount = 0; }
          if (state.rateCount >= 10) throw new HttpsError('resource-exhausted', 'Please wait before sending another message.');
          state.rateCount++;
        }
        if (input.action === 'bookmark') state.bookmarks = [...new Set([...state.bookmarks, input.text!])].slice(-50);
```
