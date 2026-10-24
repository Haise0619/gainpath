import {expect,it,vi} from 'vitest';
import {MemoryStore} from './memory-store';
import {ensureCoachCalendar} from '../src/modules/coaching/gym-calendar-mapping';
it('reserves calendar creation, reuses the mapping and rejects a different Google subject',async()=>{
 const s=new MemoryStore();s.documents.set('orgs/org/members/coach',{role:'coach',status:'active',organizationId:'org'});s.documents.set('system/googleGym/orgs/org',{status:'connected',subject:'sub',secretId:'conn'});
 const create=vi.fn(async()=>({calendarId:'created@group.calendar.google.com'}));
 const results=await Promise.allSettled([ensureCoachCalendar(s,'org','coach','sub','conn',create),ensureCoachCalendar(s,'org','coach','sub','conn',create)]);expect(results.some(r=>r.status==='fulfilled')).toBe(true);expect(create).toHaveBeenCalledOnce();
 expect(await ensureCoachCalendar(s,'org','coach','sub','conn',create)).toBe('created@group.calendar.google.com');
 await expect(ensureCoachCalendar(s,'org','coach','other','conn',create)).rejects.toBeDefined();
});
it('does not create a second calendar after an uncertain creation',async()=>{const s=new MemoryStore();s.documents.set('orgs/org/members/coach',{role:'coach',status:'active',organizationId:'org'});s.documents.set('system/googleGym/orgs/org',{status:'connected',subject:'sub',secretId:'conn'});const create=vi.fn().mockRejectedValue(Error('timeout'));
 await expect(ensureCoachCalendar(s,'org','coach','sub','conn',create)).rejects.toBeDefined();await expect(ensureCoachCalendar(s,'org','coach','sub','conn',create)).rejects.toBeDefined();expect(create).toHaveBeenCalledOnce();});
