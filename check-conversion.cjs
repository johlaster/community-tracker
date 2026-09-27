const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8');
const code=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1].replace(/init\(\);\s*$/,'');
const ctx=vm.createContext({location:{hash:''},document:{querySelector:()=>null},console});vm.runInContext(code,ctx);
vm.runInContext(`
  people=[{id:'p1',name:'Anna',customer_status:'through_event'},{id:'p2',name:'Ben',customer_status:'none'},{id:'p3',name:'Clara',customer_status:'through_event'}];
  events=[{id:'e1',title:'Januar',event_date:'2026-01-01',status:'Abgeschlossen'},{id:'e2',title:'Februar',event_date:'2026-02-01',status:'Abgeschlossen'}];
  participations=[{id:'a1',event_id:'e1',person_id:'p1',attended:true},{id:'a2',event_id:'e1',person_id:'p2',attended:true},{id:'a3',event_id:'e2',person_id:'p1',attended:true},{id:'a4',event_id:'e2',person_id:'p3',attended:true}];
  selectedEventId='e2';
`,ctx);
const conversion=vm.runInContext(`eventConversion('e2')`,ctx);
assert.equal(conversion.newPeople,1);assert.equal(conversion.newCustomers,1);assert.equal(conversion.rate,100);
const detail=vm.runInContext('eventConversionDetail()',ctx);assert(detail.includes('1'));assert(detail.includes('100 %'));
const overview=vm.runInContext('conversionOverview()',ctx);assert(overview.includes('Event-Conversion'));assert(overview.includes('Kunden durch Events'));
console.log('PASS: first-visit detection, event customer conversion, and dashboard conversion overview');
