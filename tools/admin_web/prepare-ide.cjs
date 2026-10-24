// Uses the existing approved local App Check registration. No cloud calls.
const fs=require('node:fs'),path=require('node:path');
function prepareIde(root,fixturePath){
 const file=fixturePath||path.join(root,'build/non-core-crud-sprint/module-8-activation/private/admin-web-app-check.json');
 const fixture=JSON.parse(fs.readFileSync(file,'utf8'));
 if(fixture.registered!==true||typeof fixture.token!=='string'||!fixture.token.trim())throw Error('Existing registered local Admin App Check fixture required');
 const out=path.join(root,'build/local-run/admin.firebase.json');fs.mkdirSync(path.dirname(out),{recursive:true});
 fs.writeFileSync(out,JSON.stringify({APP_CHECK_MODE:'debug',APP_CHECK_WEB_DEBUG_TOKEN:fixture.token},null,2));return out;
}
if(require.main===module){try{console.log(JSON.stringify({prepared:prepareIde(path.resolve(__dirname,'../..'),process.env.GAINPATH_ADMIN_APP_CHECK_FIXTURE),backend:'firebase',registeredNewToken:false}));}catch{console.error('Cannot prepare IDE config: supply the existing private Admin App Check fixture. No token was registered or printed.');process.exitCode=1;}}
module.exports={prepareIde};
