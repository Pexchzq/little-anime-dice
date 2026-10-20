import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import vm from 'node:vm';
const html=fs.readFileSync(new URL('../report.html',import.meta.url),'utf8');
const initial={gameId:10708913337,userId:1,claimed:1,total:7,cooldown:82800,nextAt:1792453527,serverObservedAt:1792371296,serverOffset:0};
function page(state,now){const nodes={};const make=()=>({textContent:'',children:[],append(...v){this.children.push(...v)},addEventListener(){}});
 const get=id=>nodes[id]??=(make());get('state').textContent=JSON.stringify(state);
 const context=vm.createContext({document:{getElementById:get,createElement:make},Intl,Date,Number,String,Math,JSON,setInterval(){},location:{reload(){}}});
 const source=html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];vm.runInContext(source,context);vm.runInContext(`render(${now})`,context);return nodes;}
test('offline page computes captured next login even when reopened later with no game connection',()=>{
 assert.equal(page(initial,1792371296000).countdown.textContent,'22 : 50 : 31');
 const next=page(initial,1792453528000);assert.equal(next.countdown.textContent,'ถึงเวลารับแล้ว');assert.equal(next.days.children.length,7);
 assert.match(next.note.textContent,/เข้าเกม/);assert.match(next.sync.textContent,/ไม่ใช่สถานะสด/);
});
test('native server clock offset is preserved instead of using arbitrary system clock',()=>{
 assert.equal(page({...initial,serverOffset:120},1792371176000).countdown.textContent,'22 : 50 : 31');
});
test('day 7 complete cannot show a made-up day 8; invalid data is not ready',()=>{
 const done=page({...initial,claimed:7,nextAt:undefined},1792453528000);assert.equal(done.countdown.textContent,'ครบ 7 / 7');
 assert.equal(page({...initial,gameId:5578556129},1792453528000).countdown.textContent,'ยังคำนวณไม่ได้');
});
test('an unconfirmed request is not presented as a received reward',()=>{
 assert.match(page({...initial,reason:'claim_unconfirmed'},1792453528000).note.textContent,/ยังไม่นับว่าได้รับรางวัล/);
 assert.doesNotMatch(html,/https?:\/\//,'offline page has no external network dependency');
});
