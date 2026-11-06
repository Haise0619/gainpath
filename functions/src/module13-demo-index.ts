/** Prepared selective demo entrypoint. The normal production index is unchanged. */
import {initializeApp} from 'firebase-admin/app';
initializeApp();
export {module13DemoAdminCommand,module13DemoMemberCommand,module13DemoDeliveryCommand} from './modules/recommendation/demo-callables';
