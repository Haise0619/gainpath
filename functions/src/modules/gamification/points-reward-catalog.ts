import {createHash} from 'node:crypto';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {InputValidationError,requiredIdentifier} from '../../platform/validation';
import {readAll,type DocumentStore,type DocumentData} from '../../platform/firestore/store';
import {authorizeRewardsAdmin,parseRewardPolicy} from './verified-rewards-service';
import {rewardItemDetails} from './reward-details';
import {parsePointsRewardShop,pointsRewardItem,rewardCatalogIds,POINTS_SHOP_VERSION} from './points-reward-shop';
type Auth={uid:string;token:Record<string,unknown>}|undefined;
const hash=(v:unknown)=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
const integer=(v:unknown,min=0):v is number=>Number.isSafeInteger(v)&&Number(v)>=min;
const fail=(message='Reward catalog is unavailable.')=>new DomainError('failed-precondition',message);
function published(raw:DocumentData|undefined,itemId:string,org:string) {
  const item=pointsRewardItem(raw,itemId,org),details=rewardItemDetails(raw!);
  if (!details) throw fail('Review legacy reward details before editing.');
  return {...item,active:raw!.active,category:raw!.category??'Merchandise',...details};
}
export async function pointsRewardCatalogCommand(store:DocumentStore,auth:Auth,raw:unknown,clock:()=>number) {
  requireVerifiedEmail(auth);
  if (!raw||typeof raw!=='object'||Array.isArray(raw)) throw new InputValidationError('Reward command required.');
  const d=raw as DocumentData;
  const actions:Record<string,string[]>={pointsOverview:[],savePoints:['requestId','itemId','baseItemRevision','title','description','category','imageUrl','pointCost','stockToAdd','validityDays','conditions','collectionInstructions'],retirePoints:['requestId','itemId','baseItemRevision']};
  const action=String(d.action),fields=['schemaVersion','organizationId','action',...(actions[action]??[])];
  if (d.schemaVersion!==1||!Object.hasOwn(actions,action)||Object.keys(d).length!==fields.length||Object.keys(d).some(k=>!fields.includes(k))) throw new InputValidationError('Invalid points reward fields.');
  const org=requiredIdentifier(d.organizationId,'organizationId'),uid=requiredIdentifier(auth!.uid,'uid');
  if(action!=='pointsOverview'){
    requiredIdentifier(d.requestId,'requestId');requiredIdentifier(d.itemId,'itemId');
    if(!integer(d.baseItemRevision))throw new InputValidationError('Invalid reward revision.');
  }
  if(action==='savePoints'&&(!integer(d.pointCost,1)||!integer(d.stockToAdd)||!integer(d.validityDays,1)||d.validityDays>365||
    typeof d.title!=='string'||!d.title.trim()||d.title.trim().length>120||typeof d.description!=='string'||typeof d.imageUrl!=='string'||
    !['Merchandise','Food & Drink','Apparel','Access Pass'].includes(String(d.category))))throw new InputValidationError('Enter valid reward details, points, stock and validity.');
  const fingerprint=hash(Object.keys(d).sort().map(k=>[k,d[k]]));
  return store.transact(async tx=>{
    const now=clock();if(!integer(now,1)||now>8640000000000000)throw fail();
    await authorizeRewardsAdmin(tx,auth!,org);
    const opPath=`orgs/${org}/rewardCatalogOperations/${hash([uid,d.requestId])}`;
    if(action!=='pointsOverview'){
      const prior=await tx.get(opPath);
      if(prior){if(prior.schemaVersion!==1||prior.organizationId!==org||prior.adminId!==uid||prior.requestId!==d.requestId||prior.action!==action||prior.fingerprint!==fingerprint)throw new DomainError('already-exists','Request already used for another operation.');return {schemaVersion:1,organizationId:org,confirmed:true};}
    }
    const shopPath=`orgs/${org}/rewardShops/current`;
    const [shopRaw,legacy]=await readAll(tx,[shopPath,`orgs/${org}/rewardPolicies/current`]);
    const shop=parsePointsRewardShop(shopRaw,org);
    let itemIds=shop?.itemIds??[],catalogItemIds=shop?.catalogItemIds??[];
    if(!shop&&legacy){
      const p=parseRewardPolicy({...legacy,enabled:true},org,Number(legacy.effectiveFromMillis));if(!p||typeof legacy.enabled!=='boolean')throw fail();
      itemIds=rewardCatalogIds(p.itemIds);catalogItemIds=rewardCatalogIds(legacy.catalogItemIds??itemIds);
      if(itemIds.some(i=>!catalogItemIds.includes(i)))throw fail();
    }
    if(action==='pointsOverview'){
      const items=await readAll(tx,catalogItemIds.map(id=>`orgs/${org}/rewardItems/${id}`));
      return {schemaVersion:1,organizationId:org,items:items.map((item,i)=>published(item,catalogItemIds[i],org))};
    }
    const itemId=String(d.itemId),itemPath=`orgs/${org}/rewardItems/${itemId}`,existing=await tx.get(itemPath);
    if((existing?.revision??0)!==d.baseItemRevision)throw new DomainError('aborted','Reward changed. Refresh before saving.');
    if(existing)published(existing,itemId,org);
    let next:DocumentData;
    if(action==='retirePoints'){
      if(!existing)throw fail('Reward no longer exists.');
      next={...existing,active:false,revision:Number(existing.revision)+1};itemIds=itemIds.filter(id=>id!==itemId);
    }else{
      const details=rewardItemDetails({rewardDetailsVersion:1,description:d.description,imageUrl:d.imageUrl,validityDays:d.validityDays,conditions:d.conditions,collectionInstructions:d.collectionInstructions})!;
      const stock=Number(existing?.stock??0)+Number(d.stockToAdd);if(!integer(stock))throw fail('Reward stock is outside supported limits.');
      if(!catalogItemIds.includes(itemId)&&catalogItemIds.length>=100)throw fail('Reward catalog limit reached.');
      next={schemaVersion:1,organizationId:org,itemId,title:String(d.title).trim(),category:d.category,active:true,pricingMode:'points_only',pointCost:d.pointCost,stock,premiumOnly:false,revision:Number(d.baseItemRevision)+1,...details};
      itemIds=[...new Set([...itemIds,itemId])];catalogItemIds=[...new Set([...catalogItemIds,itemId])];
    }
    tx.set(itemPath,{...next,updatedBy:uid,updatedAtMillis:now});
    tx.set(shopPath,{schemaVersion:1,organizationId:org,version:POINTS_SHOP_VERSION,itemIds,catalogItemIds,updatedBy:uid,updatedAtMillis:now});
    tx.create(opPath,{schemaVersion:1,organizationId:org,adminId:uid,requestId:d.requestId,action,fingerprint,confirmedAtMillis:now});
    return {schemaVersion:1,organizationId:org,confirmed:true};
  });
}
