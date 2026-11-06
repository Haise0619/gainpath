/** Pure offline evaluation. Never registers an endpoint or invokes a provider. */
export type IndependentLabels = Readonly<Record<string,0|1|2|3>>;
export function evaluateIndependentOrder(ids:readonly string[], eligible:readonly string[], labels:IndependentLabels|null) {
  if(new Set(ids).size!==ids.length)throw Error('duplicate_returned_target');
  if(new Set(eligible).size!==eligible.length)throw Error('duplicate_eligible_target');
  if(labels!==null){
    if(Object.values(labels).some(v=>!Number.isInteger(v)||v<0||v>3))throw Error('invalid_labels');
    if(Object.keys(labels).length!==eligible.length||eligible.some(id=>!Object.hasOwn(labels,id)))throw Error('incomplete_labels');
  }
  const effectiveK=Math.min(3,eligible.length), invalidTargetCount=ids.filter(id=>!eligible.includes(id)).length;
  const grades=labels===null?null:ids.map(id=>eligible.includes(id)?labels[id]:0);
  const dcg=(values:readonly number[])=>values.slice(0,3).reduce((sum,g,i)=>sum+(2**g-1)/Math.log2(i+2),0);
  const ideal=labels===null?0:dcg(Object.values(labels).sort((a,b)=>b-a));
  return {effectiveK,returnedCount:ids.length,eligibleCount:eligible.length,invalidTargetCount,
    precisionAt1:!effectiveK||grades===null?null:Number((grades[0]??0)>0),
    precisionAt3:!effectiveK||grades===null?null:grades.slice(0,3).filter(g=>g>0).length/effectiveK,
    nDcgAt3:grades===null||!ideal?null:dcg(grades)/ideal,
    validTargetRate:ids.length?(ids.length-invalidTargetCount)/ids.length:null,
    // Unsupported means an ineligible target or a returned item assigned human grade 0.
    unsupportedRecommendationRate:!ids.length||grades===null?null:grades.filter(g=>g===0).length/ids.length};
}
export function summarizeMeasurements(values:readonly (number|null)[]) {
  if(values.some(v=>v!==null&&(!Number.isFinite(v)||v<0)))throw Error('invalid_measurement');
  const known=values.filter((v):v is number=>v!==null),n=known.length;
  const mean=n?known.reduce((s,v)=>s+v,0)/n:null;
  return {mean,n,missing:values.length-n,min:n?Math.min(...known):null,max:n?Math.max(...known):null,
    standardError:n>1?Math.sqrt(known.reduce((s,v)=>s+(v-mean!)**2,0)/(n-1)/n):null};
}
export function rateWithUncertainty(numerator:number,denominator:number) {
  if(!Number.isInteger(numerator)||!Number.isInteger(denominator)||numerator<0||denominator<numerator)throw Error('invalid_rate');
  if(!denominator)return{numerator,denominator,rate:null,wilson95:null};
  const rate=numerator/denominator,z=1.959963984540054,scale=1+z*z/denominator;
  const center=(rate+z*z/(2*denominator))/scale;
  const radius=z*Math.sqrt(rate*(1-rate)/denominator+z*z/(4*denominator**2))/scale;
  return{numerator,denominator,rate,wilson95:[Math.max(0,center-radius),Math.min(1,center+radius)]};
}
/** Caller must group only observations with identical input/model/prompt/config hashes. */
export function compareRepeatedOrders(orders:readonly (readonly string[])[]) {
  if(orders.some(o=>new Set(o).size!==o.length))throw Error('duplicate_returned_target');
  let comparisons=0,exact=0,jaccard=0;
  for(let i=0;i<orders.length;i++)for(let j=i+1;j<orders.length;j++){
    comparisons++;exact+=Number(JSON.stringify(orders[i])===JSON.stringify(orders[j]));
    const a=orders[i].slice(0,3),b=orders[j].slice(0,3),union=new Set([...a,...b]);
    jaccard+=union.size?a.filter(id=>b.includes(id)).length/union.size:1;
  }
  return{comparisons,exactAgreement:comparisons?exact/comparisons:null,meanTop3Jaccard:comparisons?jaccard/comparisons:null};
}
