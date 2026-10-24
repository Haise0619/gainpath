import {expect,it,vi} from 'vitest';
import {GoogleSecretVault} from '../src/modules/coaching/google-secret-vault';
const id='gainpath-google-01234567890123456789-11111111-1111-1111-1111-111111111111';
it('uses a dedicated secret and authenticated body payload, then deletes on disconnect',async()=>{
 const fetcher=vi.fn().mockResolvedValueOnce(new Response('{}')).mockResolvedValueOnce(new Response('{}'))
 .mockResolvedValueOnce(new Response(JSON.stringify({payload:{data:Buffer.from(JSON.stringify({refreshToken:'PRIVATE_REFRESH'})).toString('base64')}})))
 .mockResolvedValueOnce(new Response('{}'));
 const vault=new GoogleSecretVault('gainpath-0619',fetcher,async()=> 'ADC_ACCESS');
 await vault.put(id,{refreshToken:'PRIVATE_REFRESH'});expect(await vault.read(id)).toEqual({refreshToken:'PRIVATE_REFRESH'});await vault.destroy(id);
 expect(fetcher.mock.calls[0][0]).toBe('https://secretmanager.googleapis.com/v1/projects/gainpath-0619/secrets?secretId='+id);
 expect(fetcher.mock.calls[1][0]).toContain(id+':addVersion');expect(fetcher.mock.calls[3][1].method).toBe('DELETE');expect(JSON.stringify(fetcher.mock.calls.map(c=>c[0]))).not.toContain('PRIVATE_REFRESH');
});
it('rejects arbitrary secret names before credential or network access',async()=>{const fetcher=vi.fn(),token=vi.fn();const vault=new GoogleSecretVault('gainpath-0619',fetcher,token);await expect(vault.read('GEMINI_API_KEY')).rejects.toBeDefined();expect(fetcher).not.toHaveBeenCalled();expect(token).not.toHaveBeenCalled();});
