import {expect,it} from 'vitest';
import {bookingPaymentCommandError} from '../src/modules/commerce/booking-payment-callables';
import {BookingQuoteChangedError} from '../src/modules/commerce/booking-payment-service';
it('preserves explicit no-checkout quote-change details at callable boundary',()=>{
 expect(bookingPaymentCommandError(new BookingQuoteChangedError())).toMatchObject({code:'failed-precondition',details:{reason:'quote_changed',checkoutCreated:false}});
});
