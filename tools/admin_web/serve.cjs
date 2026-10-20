const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../../build/admin-web/current');
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json','.wasm':'application/wasm','.css':'text/css','.png':'image/png','.svg':'image/svg+xml','.woff2':'font/woff2','.ttf':'font/ttf','.bin':'application/octet-stream'};
function handler(req,res) {
  if (!['GET','HEAD'].includes(req.method)) {res.writeHead(405);return res.end();}
  try {
    const name = decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    if (name.startsWith('/builds/')) {res.writeHead(302,{Location:'/', 'Cache-Control':'no-store'});return res.end();}
    let file=path.resolve(root,'.'+name);
    if (file!==root && !file.startsWith(root+path.sep)) {res.writeHead(403);return res.end();}
    if (fs.existsSync(file)&&fs.statSync(file).isDirectory()) file=path.join(file,'index.html');
    if (!fs.existsSync(file)) {if(path.extname(name)){res.writeHead(404);return res.end();}file=path.join(root,'index.html');}
    if (!fs.existsSync(file)) {res.writeHead(503);return res.end('Build the main Admin first: node tools/admin_web/build.cjs');}
    res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store','X-GainPath-Admin':'main'});
    if (req.method==='HEAD') return res.end();
    fs.createReadStream(file).pipe(res);
  } catch {res.writeHead(400);res.end();}
}
if(require.main===module) http.createServer(handler).listen(7359,'127.0.0.1',()=>console.log('GainPath main Admin: http://localhost:7359/'));
module.exports={handler};
