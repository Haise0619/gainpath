import {randomUUID} from 'node:crypto';
import type {DocumentStore} from '../../platform/firestore/store';
import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {coachCalendarPath,gymConnectionPath} from './google-gym-connection';

/** The creation receipt precedes IO: an ambiguous POST must never create twice. */
export async function ensureCoachCalendar(store:DocumentStore,org:string,coach:string,subject:string,connectionId:string,create:()=>Promise<{calendarId:string}>){
 requiredIdentifier(org,'organizationId');requiredIdentifier(coach,'coachId');const path=coachCalendarPath(org,coach),attempt=randomUUID();
 const existing=await store.transact(async tx=>{
  const grant=await tx.get(gymConnectionPath(org)),m=await tx.get(`orgs/${org}/members/${coach}`),old=await tx.get(path);
  if(grant?.status!=='connected'||grant.subject!==subject||grant.secretId!==connectionId||m?.organizationId!==org||m.role!=='coach'||m.status!=='active')throw new DomainError('permission-denied','Calendar assignment is unavailable.');
  if(old){if(old.subject!==subject||old.coachId!==coach||old.status!=='ready'||typeof old.calendarId!=='string')throw new DomainError('failed-precondition','Calendar creation needs Admin reconciliation. Do not create another calendar.');return String(old.calendarId);}
  tx.create(path,{schemaVersion:1,coachId:coach,subject,status:'creating',attempt});return undefined;
 });if(existing)return existing;
 try{
  const created=await create();if(!created.calendarId||created.calendarId.length>512)throw Error();
  return await store.transact(async tx=>{const old=await tx.get(path),grant=await tx.get(gymConnectionPath(org));if(old?.attempt!==attempt||old.status!=='creating')throw Error();
   const current=grant?.status==='connected'&&grant.subject===subject&&grant.secretId===connectionId;
   tx.set(path,{...old,calendarId:created.calendarId,status:current?'ready':'needs_review'});return created.calendarId;});
 }catch{await store.transact(async tx=>{const old=await tx.get(path);if(old?.attempt===attempt&&old.status==='creating')tx.set(path,{...old,status:'uncertain'});});throw new DomainError('unavailable','Calendar creation is uncertain. Admin must reconcile it before retrying.');}
}
