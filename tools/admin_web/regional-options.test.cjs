const {test}=require('node:test'),assert=require('node:assert/strict');
const {regionalBuildDefines}=require('./regional-options.cjs');
test('normal builds preserve existing defaults; approved names opt in explicitly',()=>{
 assert.deepEqual(regionalBuildDefines({}),[]);
 assert.deepEqual(regionalBuildDefines({SINGAPORE_CALLABLES:' getCoachRosterCommand,getCoachCertificationsCommand,getCoachRosterCommand '}),['--dart-define=SINGAPORE_CALLABLES=getCoachRosterCommand,getCoachCertificationsCommand']);
 assert.deepEqual(regionalBuildDefines({BOOKING_READS_REGION:'us-central1',COACH_RATINGS_REGION:'us-central1'}),['--dart-define=BOOKING_READS_REGION=us-central1','--dart-define=COACH_RATINGS_REGION=us-central1']);
});
test('reject held or undeployed commands, background jobs and malformed region configuration',()=>{
 for(const value of ['verifiedRewardsCommand','paymentWebhook','unknown','*','getCoachRosterCommand,'])assert.throws(()=>regionalBuildDefines({SINGAPORE_CALLABLES:value}));
 assert.throws(()=>regionalBuildDefines({BOOKING_READS_REGION:'invalid'}));
});
