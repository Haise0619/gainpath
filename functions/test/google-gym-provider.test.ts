import {expect,it,vi} from 'vitest';
import {GoogleGymProvider} from '../src/modules/coaching/google-gym-provider';
it('keeps credentials in form POST bodies and verifies the returned Google identity',async()=>{
 const fetcher=vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({access_token:'ACCESS',refresh_token:'REFRESH',scope:'openid email'})))
  .mockResolvedValueOnce(new Response(JSON.stringify({sub:'subject',email:'gym@example.com',email_verified:true})));
 const p=new GoogleGymProvider('client','CLIENT_SECRET',fetcher);const g=await p.exchange({code:'CODE',verifier:'VERIFIER',redirectUri:'https://example.com/callback'});
 expect(g.subject).toBe('subject');expect(fetcher.mock.calls[0][0]).toBe('https://oauth2.googleapis.com/token');expect(String(fetcher.mock.calls[0][1].body)).toContain('code_verifier=VERIFIER');
 expect(JSON.stringify(fetcher.mock.calls.map(c=>c[0]))).not.toContain('SECRET');expect(fetcher.mock.calls[0][1].redirect).toBe('error');
});
it('sanitizes errors and identifies a revoked refresh grant without logging token data',async()=>{
 const p=new GoogleGymProvider('client','SECRET',vi.fn().mockResolvedValue(new Response(JSON.stringify({error:'invalid_grant',description:'SECRET'}),{status:400})));
 await expect(p.refresh('REFRESH')).rejects.toMatchObject({code:'failed-precondition'});
});
it('revokes an issued grant if identity lookup fails and reports failed cleanup',async()=>{
 const fetcher=vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({access_token:'ACCESS',refresh_token:'REFRESH',scope:'openid email'})))
 .mockRejectedValueOnce(Error('userinfo timeout')).mockRejectedValueOnce(Error('revoke timeout'));
 const p=new GoogleGymProvider('client','SECRET',fetcher);
 await expect(p.exchange({code:'CODE',verifier:'VERIFIER',redirectUri:'https://example.com/callback'})).rejects.toMatchObject({revocationPending:true});
 expect(fetcher).toHaveBeenCalledTimes(3);expect(fetcher.mock.calls[2][0]).toBe('https://oauth2.googleapis.com/revoke');
});
