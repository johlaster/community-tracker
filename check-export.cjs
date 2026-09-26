const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8');
const code=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1].replace(/init\(\);\s*$/,'');
let blob,download,clicked=0;
const ctx=vm.createContext({location:{hash:''},Blob,URL:{createObjectURL:b=>{blob=b;return'blob:test'},revokeObjectURL:()=>{}},setTimeout:()=>{},document:{querySelector:()=>null,body:{appendChild:()=>{}},createElement:()=>({click(){clicked++;download=this.download},remove(){}})},console});
vm.runInContext(code,ctx);
vm.runInContext(`people=[{id:'p1',name:'=HYPERLINK("bad")',customer:true},{id:'p2',name:'Anna; Zwei',customer:false}];events=[{id:'12345678-aaaa',title:'Abend "A"',event_date:'2024-01-05',status:'Abgeschlossen',location:'Club'}];participations=[{event_id:'12345678-aaaa',person_id:'p1',response:'yes',attended:true},{event_id:'12345678-aaaa',person_id:'p2',response:'no',attended:false,brought_by:'p1'}];eventFilter='Alle'`,ctx);
(async()=>{
 vm.runInContext('exportEvents()',ctx);let csv=await blob.text();assert.deepEqual([...new Uint8Array(await blob.arrayBuffer()).slice(0,3)],[239,187,191]);assert(csv.includes('"Abend ""A"""'));assert(csv.includes('"1";"1";"0"'));assert(download.startsWith('community-events-'));
 vm.runInContext("exportEvent('12345678-aaaa')",ctx);csv=await blob.text();assert(csv.includes("'=HYPERLINK"));assert(csv.includes('"Anna; Zwei"'));assert(csv.includes('"Zusage";"Ja";"Ja"'));assert(csv.includes('"Absage";"Nein";"Nein"'));assert.equal(download,'community-event-2024-01-05-12345678.csv');assert.equal(clicked,2);
 console.log('PASS: overall and event CSV, Excel delimiter/encoding, quotes, formula protection, download');
})().catch(e=>{console.error(e);process.exitCode=1});
