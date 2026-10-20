import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {createHash} from 'node:crypto';
const root=path.dirname(fileURLToPath(import.meta.url));
const long=s=>{let n=1;while(s.includes(']'+'='.repeat(n)+']'))n++;return '['+'='.repeat(n)+'['+s+']'+'='.repeat(n)+']';};
const model=fs.readFileSync(path.join(root,'daily.lua'),'utf8');const runtime=fs.readFileSync(path.join(root,'runtime.lua'),'utf8');const html=fs.readFileSync(path.join(root,'report.html'),'utf8');
const integration=fs.readFileSync(path.join(root,'masterp.lua'),'utf8');
const bundle=`-- GENERATED Anime Dice Daily Login 1.0.4\nlocal Daily=assert(loadstring(${long(model)},'@dice-daily/model'))()\nlocal Masterp=assert(loadstring(${long(integration)},'@dice-daily/masterp'))()\nreturn assert(loadstring(${long(runtime)},'@dice-daily/runtime'))(Daily,${long(html)},Masterp)\n`;
fs.writeFileSync(path.join(root,'dice_daily_login_1_0_4.lua'),bundle);
console.log(JSON.stringify({file:'dice_daily_login_1_0_4.lua',bytes:Buffer.byteLength(bundle),sha256:createHash('sha256').update(bundle).digest('hex')}));
