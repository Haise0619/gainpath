import {DomainError} from '../../platform/errors';
import {readAll,type TransactionPort} from '../../platform/firestore/store';
import {authorizeAdminReport} from '../analytics/admin-reporting';
import {fypDigest} from './fyp-integrity';
import type {FypIdentity,FypRequest} from './fyp-scope';

export const UNIFIED_ADMIN_GATE='orgs/gainpath/adminDataIntegrations/fyp-v1';
const root='orgs/gainpath/cohorts/fyp-v1';
const deny=()=>new DomainError('permission-denied','Current canonical Admin access is required.');
export function checkUnifiedAdminIdentity(request:FypRequest,current:FypIdentity):void {
 const a=request.auth;
 if(!request.app?.appId||!a||a.token.email_verified!==true||typeof a.token.email!=='string'||!Number.isSafeInteger(a.token.auth_time))throw deny();
 if(!/^[A-Za-z0-9_-]{1,128}$/.test(a.uid)||current.uid!==a.uid||current.disabled||!current.emailVerified||current.email!==a.token.email||!Number.isFinite(current.tokensValidAfterMillis)||!Number.isSafeInteger(current.creationTimeMillis)||current.creationTimeMillis<1||Number(a.token.auth_time)*1000<Math.max(current.tokensValidAfterMillis,current.creationTimeMillis))throw deny();
}
/** Current canonical authority only. No role claim or fictional Admin alias. */
export async function authorizeUnifiedAdmin(tx:TransactionPort,request:FypRequest):Promise<{fingerprint:string;branchIds:string[]}> {
 if(!request.auth||!request.app?.appId)throw deny();
 const uid=request.auth.uid;
 await authorizeAdminReport(tx,request.auth,'gainpath');
 const [user,member,assignment,gate,cohort,gateOwner]=await readAll(tx,[`users/${uid}`,`orgs/gainpath/members/${uid}`,`datasetAssignments/${uid}`,UNIFIED_ADMIN_GATE,root,`${root}/unifiedSampleOwnership/${fypDigest(UNIFIED_ADMIN_GATE)}`]);
 if(!gateOwner||Object.keys(gateOwner).length!==4||gateOwner.schemaVersion!==1||gateOwner.seedId!=='unified-admin-business-v1'||gateOwner.path!==UNIFIED_ADMIN_GATE||gateOwner.digest!==fypDigest(gate))throw deny();
 if(assignment||!user||user.status!==undefined&&user.status!=='active'||!member||member.userId!==undefined&&member.userId!==uid||!gate||Object.keys(gate).length!==6||gate.schemaVersion!==1||gate.organizationId!=='gainpath'||gate.cohortId!=='fyp-v1'||gate.rootPath!==root||gate.enabled!==true||gate.version!=='unified-admin-v1'||cohort?.schemaVersion!==1||cohort.organizationId!=='gainpath'||cohort.datasetId!=='fyp-v1'||cohort.seedId!=='gainpath-fyp-v1'||cohort.enabled!==true||cohort.status!=='active')throw deny();
 const branchIds=member.branchIds as string[];
 if(branchIds.length>50||branchIds.some(x=>!/^[A-Za-z0-9_-]{1,128}$/.test(x))||new Set(branchIds).size!==branchIds.length)throw deny();
 return{fingerprint:fypDigest({organizationId:user.organizationId,role:user.role??null,status:user.status??null,lifecycle:user.accountLifecycle??null,member:{role:member.role,status:member.status,branchIds,userId:member.userId??null},gate,cohort:{enabled:cohort.enabled,status:cohort.status,seedId:cohort.seedId}}),branchIds};
}
