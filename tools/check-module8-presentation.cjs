const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'apps/mobile/lib/features/identity/presentation/coach');
const violations=[];
for(const file of fs.readdirSync(folder).filter(f=>f.endsWith('.dart'))){
 const source=fs.readFileSync(path.join(folder,file),'utf8');
 if(/(?:import|export)\s+['"][^'"]*(?:infrastructure\/firebase|package:firebase_|package:cloud_firestore|package:cloud_functions)/.test(source))violations.push(file+': presentation depends on Firebase SDK/adapter');
 if(/\bclass\s+LiveCoach(?:Account|Profile|Settings|Certifications)/.test(source))violations.push(file+': duplicate live page class');
 if(/\bif\s*\(\s*(?:firebaseMode|isFirebase|liveRepository\s*!=)/.test(source))violations.push(file+': backend chooses page body');
}
if(violations.length){console.error(violations.join('\n'));process.exitCode=1;}else console.log('Module 8 presentation boundary passed: no Firebase dependencies or duplicate live page classes.');
