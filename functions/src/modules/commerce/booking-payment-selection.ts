import {DomainError} from '../../platform/errors';
import type {DocumentData} from '../../platform/firestore/store';

// Product preferences, not evidence that a provider rail is enabled or used.
export const bookingPaymentSelections = [
  ['fpx','maybank2u','Maybank2u','maybank'],['fpx','cimbclicks','CIMB Clicks','cimb'],
  ['fpx','publicbank','Public Bank','public_bank'],['fpx','rhb','RHB','rhb'],
  ['fpx','hongleong','Hong Leong Bank','hong_leong'],['fpx','bankislam','Bank Islam','bank_islam'],
  ['fpx','ambank','AmBank','ambank'],['fpx','bsn','BSN','bsn'],['fpx','affin','Affin Bank','affin'],['fpx','alliance','Alliance Bank','alliance'],
  ['ewallet','tng','Touch ’n Go eWallet','tng'],['ewallet','grabpay','GrabPay','grabpay'],['ewallet','shopeepay','ShopeePay','shopeepay'],
  ['card','visa_mastercard','Visa / Mastercard','visa_mastercard'],
].map(([category,code,name,iconKey])=>({category,code,name,iconKey}));
export interface SelectedPaymentMetadata {
  selectedPaymentMethodCategory:string;selectedPaymentMethodCode:string;selectedPaymentMethodLabel:string;selectedPaymentMethodIconKey:string;selectedAt:number;
}
export const selectedPaymentKeys=['selectedPaymentMethodCategory','selectedPaymentMethodCode','selectedPaymentMethodLabel','selectedPaymentMethodIconKey','selectedAt'] as const;
export function selectedPaymentMetadata(code:string,at:number):SelectedPaymentMetadata {
  const method=bookingPaymentSelections.find(m=>m.code===code);
  if(!method||!Number.isSafeInteger(at)||at<1)throw new DomainError('invalid-argument','Choose a payment method.');
  return {selectedPaymentMethodCategory:method.category,selectedPaymentMethodCode:method.code,selectedPaymentMethodLabel:method.name,selectedPaymentMethodIconKey:method.iconKey,selectedAt:at};
}
export function selectedPaymentProjection(data:DocumentData):Partial<SelectedPaymentMetadata>{
  if(!selectedPaymentKeys.some(k=>data[k]!==undefined))return {};
  const expected=selectedPaymentMetadata(String(data.selectedPaymentMethodCode),Number(data.selectedAt));
  if(selectedPaymentKeys.some(k=>data[k]!==expected[k]))throw new DomainError('failed-precondition','Saved payment method needs review.');
  return expected;
}
