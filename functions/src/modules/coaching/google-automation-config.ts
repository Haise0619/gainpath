import {defineBoolean,defineString} from 'firebase-functions/params';
import type {AutomaticDeliveryConfig} from './automatic-google-delivery';
export const automaticGoogleEnabled=defineBoolean('GOOGLE_BOOKING_AUTOMATION_ENABLED',{default:false});
export const automaticGoogleRecipients=defineString('GOOGLE_BOOKING_AUTOMATION_TEST_RECIPIENTS',{default:''});
export function googleAutomationConfig():AutomaticDeliveryConfig {
 // Keep the activation timestamp genuinely absent in disabled deployments.
 // A declared Firebase string parameter would materialize its empty default.
 const raw=process.env.GOOGLE_BOOKING_AUTOMATION_ACTIVATED_AT??'';
 return {enabled:automaticGoogleEnabled.value(),organizationId:process.env.GOOGLE_GYM_ORGANIZATION_ID??'',activatedAtMillis:raw?Date.parse(raw):NaN,allowedRecipients:automaticGoogleRecipients.value().split(',').map(s=>s.trim()).filter(Boolean),testCoachId:process.env.GOOGLE_BOOKING_AUTOMATION_TEST_COACH_ID??'',testBookingId:process.env.GOOGLE_BOOKING_AUTOMATION_TEST_BOOKING_ID??''};
}
