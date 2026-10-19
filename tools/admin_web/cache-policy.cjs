// Keep one official URL while bypassing code cached by older Flutter workers.
function versionLocalCode(index,bootstrap,hash){
 if(!/^[a-f0-9]{64}$/.test(hash))throw Error('Invalid local build hash');
 if(!index.includes('src="flutter_bootstrap.js"')||!bootstrap.includes('"mainJsPath":"main.dart.js"'))throw Error('Unexpected Flutter bootstrap; inspect before serving');
 return{index:index.replace('src="flutter_bootstrap.js"',`src="flutter_bootstrap.js?build=${hash}"`),bootstrap:bootstrap.replace('"mainJsPath":"main.dart.js"',`"mainJsPath":"main.dart.js?build=${hash}"`)};
}
module.exports={versionLocalCode};
