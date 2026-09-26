const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8');
const code=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1].replace(/init\(\);\s*$/,'');
const fields={'#pName':{value:'Ben Neu'},'#pCustomer':{checked:false},'#pReferrer':{value:'p1'}};
const calls=[],alerts=[];let loaded=0;
const ctx=vm.createContext({location:{hash:''},document:{querySelector:s=>fields[s]},alert:x=>alerts.push(x),console});
vm.runInContext(code,ctx);
vm.runInContext(`session={user:{id:'owner'}};people=[{id:'p1',name:'Anna',referred_by:null},{id:'p2',name:'Ben',referred_by:null}];events=[];participations=[];selectedPersonId='p2';modal='editPerson';setLoading=()=>{}`,ctx);
ctx.load=async()=>{loaded++};vm.runInContext('loadAll=load',ctx);
ctx.mock={from(table){calls.push(['from',table]);return {update(values){calls.push(['update',values]);return this},eq(key,value){calls.push(['eq',key,value]);return this},async select(){return{data:[{id:'p2'}],error:null}}}}};vm.runInContext('sb=mock',ctx);
(async()=>{
 const options=vm.runInContext(`referrerOptions('p2','p1')`,ctx);assert(options.includes('value="p1" selected'));assert(!options.includes('value="p2"'));
 await vm.runInContext('savePerson()',ctx);const update=calls.find(c=>c[0]==='update')[1];assert.equal(update.referred_by,'p1');assert.equal(loaded,1);
 vm.runInContext(`people[1].referred_by='p1'`,ctx);const row=vm.runInContext(`personRow(people[1])`,ctx);assert(row.includes('Mitgebracht von Anna'));
 const profile=vm.runInContext('personDetail()',ctx);assert(profile.includes('Ursprünglich mitgebracht von: Anna'));
 const dash=vm.runInContext('dashboard()',ctx);assert(dash.includes('Top-Zuträger'));assert(dash.includes('Anna'));assert(dash.includes('1 Personen mitgebracht'));
 fields['#pReferrer'].value='p2';const before=calls.length;await vm.runInContext('savePerson()',ctx);assert.equal(calls.length,before);assert(alerts.at(-1).includes('gültige Person'));
 console.log('PASS: referrer choices, persistent save, profile/list display, dashboard ranking, self-reference guard');
})().catch(e=>{console.error(e);process.exitCode=1});
