const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8');
const code=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1].replace(/init\(\);\s*$/,'');
const fields={'#loading':{classList:{contains:()=>true}},'#eTitle':{value:'Mario Kart'},'#eDate':{value:'2026-10-01'},'#eStart':{value:''},'#eEnd':{value:''},'#eLocation':{value:''},'#eNotes':{value:''}};
let selected=[{value:'p2'}],loaded=0;const calls=[],alerts=[];
const ctx=vm.createContext({location:{hash:''},document:{querySelector:s=>fields[s],querySelectorAll:s=>s==='.event-person:checked'?selected:[]},alert:x=>alerts.push(x),console});
vm.runInContext(code,ctx);
vm.runInContext(`session={user:{id:'owner'}};people=[{id:'p1',name:'Anna'},{id:'p2',name:'Ben'}];setLoading=()=>{};`,ctx);
ctx.load=async()=>{loaded++};vm.runInContext('loadAll=load',ctx);
ctx.mock={from(table){calls.push(['from',table]);return {insert(rows){calls.push(['insert',rows]);if(table==='events')return {select:()=>({single:async()=>({data:{id:'e'+loaded},error:null})})};return Promise.resolve({error:null})}}}};
vm.runInContext('sb=mock',ctx);
(async()=>{
 const choices=vm.runInContext('eventInviteForm()',ctx);assert(choices.includes('Alle auswählen'));assert(choices.includes('Keine auswählen'));assert(choices.includes('Anna'));assert(choices.includes('Ben'));
 await vm.runInContext('addEvent()',ctx);
 let rows=calls.filter(c=>c[0]==='insert'&&Array.isArray(c[1])).at(-1)[1];assert.equal(rows.length,1);assert.equal(rows[0].person_id,'p2');assert.equal(loaded,1);
 selected=[];const before=calls.length;await vm.runInContext('addEvent()',ctx);assert.equal(calls.slice(before).filter(c=>c[0]==='from'&&c[1]==='participations').length,0);assert.equal(loaded,2);
 assert.equal(alerts.length,0);
 console.log('PASS: invited-person selector, selected-only creation, empty-event creation');
})().catch(e=>{console.error(e);process.exitCode=1});
