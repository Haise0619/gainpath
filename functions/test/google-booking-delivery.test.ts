import { expect, it, vi } from 'vitest';
import { GoogleBookingGateway } from '../src/modules/coaching/google-booking-delivery';
const booking={organizationId:'org',bookingId:'booking',coachId:'coach',memberId:'member',status:'confirmed',startAtMillis:1792717200000,endAtMillis:1792720800000,timeZone:'Asia/Kuala_Lumpur',coachName:'Coach',branchName:'Studio'};
it('renders distinct reschedule and cancellation messages without refund promises',async()=>{
 const bodies:string[]=[];const fetcher=vi.fn(async(_url,init)=>{const mime=Buffer.from(JSON.parse(init!.body as string).raw,'base64url').toString();bodies.push(mime.split('\r\n\r\n')[0]+'\n'+Buffer.from(mime.split('\r\n\r\n')[1],'base64').toString());return new Response(JSON.stringify({id:'message'}));});
 const g=new GoogleBookingGateway(async()=>({accessToken:'TOKEN',senderEmail:'gym@example.com'}),fetcher);
 await g.sendNotification(booking,'member@example.com',{type:'rescheduled',revision:'revision-1',previousStartAtMillis:booking.startAtMillis-3600000,previousEndAtMillis:booking.endAtMillis-3600000});
 await g.sendNotification({...booking,status:'cancelled'},'member@example.com',{type:'cancelled',revision:'revision-2'});
 expect(bodies[0]).toContain('Subject: GainPath session rescheduled');expect(bodies[0]).toContain('Previous start:');expect(bodies[0]).toContain('Start:');
 expect(bodies[1]).toContain('Subject: GainPath session cancelled');expect(bodies[1]).toContain('Refunds are subject to review in GainPath');expect(bodies[1]).not.toContain('refund has been issued');
 await expect(g.sendNotification(booking,'member@example.com',{type:'cancelled',revision:'r'})).rejects.toBeDefined();
 expect(fetcher).toHaveBeenCalledTimes(2);
});
it('uses stable calendar IDs and never puts recipient email or tokens in event text',async()=>{
 const fetcher=vi.fn().mockResolvedValueOnce({ok:false,status:404}).mockImplementationOnce(async (_url,init)=>({ok:true,status:200,json:async()=>({id:JSON.parse(init.body as string).id})}));
 const gateway=new GoogleBookingGateway(async()=>({accessToken:'SECRET',calendarId:'calendar@example.invalid',senderEmail:'gym@example.invalid'}),fetcher);
 const first=gateway.calendarEvent(booking),second=gateway.calendarEvent({...booking,startAtMillis:booking.startAtMillis+3600000,endAtMillis:booking.endAtMillis+3600000});
 expect(first.id).toBe(second.id);expect(JSON.stringify(first)).not.toContain('SECRET');
 await gateway.putCalendar(booking);
 expect(fetcher.mock.calls[0][0]).toContain('calendar/v3/calendars/');
 expect(JSON.stringify(fetcher.mock.calls[1][1].body)).not.toContain('gym@example.invalid');
});
it('rejects non-confirmed sessions and header injection before any Google request',async()=>{
 const fetcher=vi.fn(),gateway=new GoogleBookingGateway(async()=>({accessToken:'SECRET',calendarId:'calendar',senderEmail:'gym@example.invalid'}),fetcher);
 await expect(gateway.sendConfirmation({...booking,status:'cancelled'},'member@example.invalid')).rejects.toBeDefined();
 await expect(gateway.sendConfirmation(booking,'member@example.invalid\r\nBcc: attacker@example.invalid')).rejects.toBeDefined();
 expect(fetcher).not.toHaveBeenCalled();
});
it('does not automatically retry Gmail after an uncertain provider outcome',async()=>{
 const fetcher=vi.fn().mockRejectedValue(Error('timeout SECRET'));
 const gateway=new GoogleBookingGateway(async()=>({accessToken:'SECRET',calendarId:'calendar',senderEmail:'gym@example.invalid'}),fetcher);
 await expect(gateway.sendConfirmation(booking,'member@example.invalid')).rejects.toMatchObject({code:'unavailable'});
 expect(fetcher).toHaveBeenCalledTimes(1);
});
it('updates a rescheduled event with its ETag and deletes only an owned cancelled booking event',async()=>{
 const saved=new GoogleBookingGateway(async()=>({accessToken:'TOKEN'})).calendarEvent(booking);
 const fetcher=vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({...saved,etag:'etag',start:{dateTime:'old'}})))
  .mockResolvedValueOnce(new Response(JSON.stringify({id:saved.id})))
  .mockResolvedValueOnce(new Response(JSON.stringify({...saved,etag:'etag'})))
  .mockResolvedValueOnce(new Response(null,{status:204}));
 const gateway=new GoogleBookingGateway(async()=>({accessToken:'TOKEN',calendarId:'calendar'}),fetcher);
 await gateway.putCalendar(booking);expect(fetcher.mock.calls[1][1].method).toBe('PATCH');expect(fetcher.mock.calls[1][1].headers['If-Match']).toBe('etag');
 await gateway.removeCalendar({...booking,status:'cancelled'});expect(fetcher.mock.calls[3][1].method).toBe('DELETE');
});
it('never deletes a foreign event during cancellation',async()=>{
 const fetcher=vi.fn().mockResolvedValue(new Response(JSON.stringify({id:'foreign',etag:'e'})));
 const g=new GoogleBookingGateway(async()=>({accessToken:'TOKEN',calendarId:'calendar'}),fetcher);
 await expect(g.removeCalendar({...booking,status:'cancelled'})).rejects.toBeDefined();expect(fetcher).toHaveBeenCalledOnce();
});
it('rechecks current grant before Calendar write after its lookup',async()=>{
 let connected=true;const fetcher=vi.fn(async()=>{connected=false;return new Response(null,{status:404});});
 const g=new GoogleBookingGateway(async()=>({accessToken:'TOKEN',calendarId:'calendar',assertCurrent:async()=>{if(!connected)throw Error('disconnected');}}),fetcher);
 await expect(g.putCalendar(booking)).rejects.toMatchObject({code:'unavailable'});expect(fetcher).toHaveBeenCalledOnce();
});
