import {DomainError} from '../../platform/errors';
export interface SandboxPaymentMethod {code:string;name:string;category:'fpx'|'billplz'}
// Names identify provider codes; availability always comes from live APIs.
const banks:Record<string,string>={ABMB0212:'Alliance Bank',ABB0233:'Affin Bank',ABB0234:'Affin Bank',AMBB0209:'AmBank',AGRO01:'Agrobank',BCBB0235:'CIMB Clicks',BIMB0340:'Bank Islam',BKRM0602:'Bank Rakyat',BMMB0341:'Bank Muamalat',BOCM01:'Bank of China',BSN0601:'BSN',CIT0219:'Citibank',HLB0224:'Hong Leong Bank',HSBC0223:'HSBC',KFH0346:'Kuwait Finance House',MB2U0227:'Maybank2u',MBB0228:'Maybank2E',OCBC0229:'OCBC',PBB0233:'Public Bank',RHB0218:'RHB',SCB0216:'Standard Chartered',UOB0226:'UOB',UOB0229:'UOB Bank',MBSB001:'MBSB Bank',KAFB01:'KAF Digital Bank'};
export async function sandboxPaymentMethods(apiKey:string,collectionId:string,fetcher:typeof fetch):Promise<SandboxPaymentMethod[]> {
  const get=async(path:string)=>{
    const controller=new AbortController();let timer:ReturnType<typeof setTimeout>|undefined;
    try{return await Promise.race([(async()=>{const r=await fetcher(`https://www.billplz-sandbox.com/api/${path}`,{method:'GET',redirect:'error',headers:{Authorization:`Basic ${Buffer.from(`${apiKey}:`).toString('base64')}`},signal:controller.signal});if(!r.ok)throw Error();return await r.json() as Record<string,unknown>;})(),new Promise<never>((_,reject)=>{timer=setTimeout(()=>{controller.abort();reject(Error());},10000);})]);}
    catch{throw new DomainError('unavailable','Payment methods are temporarily unavailable.');}
    finally{if(timer)clearTimeout(timer);}
  };
  const [collection,gateways]=await Promise.all([get(`v3/collections/${collectionId}/payment_methods`),get('v4/payment_gateways')]);
  if(!collection||typeof collection!=='object'||!gateways||typeof gateways!=='object')throw new DomainError('unavailable','Payment methods are temporarily unavailable.');
  if(!Array.isArray(collection.payment_methods)||!Array.isArray(gateways.payment_gateways))throw new DomainError('unavailable','Payment methods are temporarily unavailable.');
  const valid=(rows:unknown[])=>rows.every((r)=>r && typeof r==='object' && typeof (r as Record<string,unknown>).code==='string' && typeof (r as Record<string,unknown>).active==='boolean');
  if(!valid(collection.payment_methods)||!valid(gateways.payment_gateways))throw new DomainError('unavailable','Payment methods are temporarily unavailable.');
  const enabled=new Set(collection.payment_methods.filter(m=>m.active===true).map(m=>String(m.code)));
  const result:SandboxPaymentMethod[]=[];const seen=new Set<string>();
  for(const g of gateways.payment_gateways){
    if(!g.active||seen.has(g.code)||!enabled.has(g.category))continue;
    const name=g.category==='fpx'?banks[g.code]:g.category==='billplz'&&g.code==='BP-FKR01'?'Billplz Sandbox':undefined;
    if(name){seen.add(g.code);result.push({code:g.code,name,category:g.category});}
  }
  return result.sort((a,b)=>a.category===b.category?a.name.localeCompare(b.name):a.category==='fpx'?-1:1);
}
