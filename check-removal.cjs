const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8');
const code=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1].replace(/init\(\);\s*$/,'');
let accepted=false,deleted=false,loaded=0;const calls=[],alerts=[];
const ctx=vm.createContext({location:{hash:''},document:{querySelector:()=>null},confirm:()=>accepted,alert:x=>alerts.push(x),console});
vm.runInContext(code,ctx);
vm.runInContext(`people=[{id:'p1',name:'Anna'}];events=[{id:'e1',title:'Mario Kart',event_date:'2024-01-05'}];participations=[{id:'a1',event_id:'e1',person_id:'p1',response:'yes',attended:true}];selectedEventId='e1';setLoading=()=>{}`,ctx);
ctx.load=async()=>{loaded++};vm.runInContext('loadAll=load',ctx);
ctx.mock={from(table){calls.push(['from',table]);return {delete(){deleted=true;return this},eq(key,value){calls.push(['eq',key,value]);return this},async select(){return{data:[{id:'a1'}],error:null}}}}};
vm.runInContext('sb=mock',ctx);
(async()=>{
 const detail=vm.runInContext('eventDetail()',ctx);assert(detail.includes('removeParticipant'));assert(detail.includes('Entfernen'));
 await vm.runInContext("removeParticipant('a1')",ctx);assert.equal(deleted,false);
 accepted=true;await vm.runInContext("removeParticipant('a1')",ctx);
 assert.equal(deleted,true);assert(calls.some(c=>c[0]==='eq'&&c[1]==='id'&&c[2]==='a1'));
 assert(calls.some(c=>c[0]==='eq'&&c[1]==='event_id'&&c[2]==='e1'));
 assert.equal(loaded,1);assert.equal(alerts.length,0);
 console.log('PASS: removal control, cancel, event-scoped delete, refresh');
})().catch(e=>{console.error(e);process.exitCode=1});
