const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8');
const code=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1].replace(/init\(\);\s*$/,'');
let savedBlob=null,savedName='',clicked=0,loaded=0,confirmResult=true;
const rpcCalls=[],alerts=[];
const document={
  querySelector:()=>null,
  createElement:()=>({click(){clicked++},remove(){},set download(value){savedName=value},set href(value){this._href=value}}),
  body:{appendChild(){}},
};
const ctx=vm.createContext({
  location:{hash:''},document,Blob,
  URL:{createObjectURL(blob){savedBlob=blob;return'blob:test'},revokeObjectURL(){}},
  setTimeout(){},confirm:()=>confirmResult,alert:value=>alerts.push(value),console,
});
vm.runInContext(code,ctx);
ctx.mock={async rpc(name,args){rpcCalls.push([name,args]);return{data:true,error:null}}};
ctx.load=async()=>{loaded++};
vm.runInContext(`
  session={user:{id:'owner',email:'owner@example.com'}};
  accessRole='admin';
  people=[{id:'p1',name:'Anna',user_id:'owner',referred_by:null}];
  events=[{id:'e1',title:'Freitag',event_date:'2026-09-25',user_id:'owner'}];
  participations=[{id:'a1',event_id:'e1',person_id:'p1',response:'yes',attended:true}];
  sb=mock;loadAll=load;setLoading=()=>{};
`,ctx);

(async()=>{
  vm.runInContext('exportBackup()',ctx);
  assert.equal(clicked,1);
  assert.match(savedName,/^community-tracker-sicherung-\d{4}-\d{2}-\d{2}\.json$/);
  const backup=JSON.parse(await savedBlob.text());
  assert.equal(backup.format,'community-tracker-backup');
  assert.equal(backup.version,1);
  assert.equal(backup.persons[0].name,'Anna');
  assert.equal(backup.events[0].title,'Freitag');
  assert.equal(backup.participations[0].person_id,'p1');
  assert.equal(JSON.stringify(backup).includes('owner@example.com'),false);

  vm.runInContext(`route='dashboard'`,ctx);
  assert(vm.runInContext('topbarAction()',ctx).includes('Sicherung'));
  vm.runInContext(`route='person';selectedPersonId='p1'`,ctx);
  assert(vm.runInContext('topbarAction()',ctx).includes('Person löschen'));
  vm.runInContext(`route='event';selectedEventId='e1'`,ctx);
  assert(vm.runInContext('topbarAction()',ctx).includes('Event löschen'));

  confirmResult=false;
  await vm.runInContext(`deletePerson('p1')`,ctx);
  assert.equal(rpcCalls.length,0);

  confirmResult=true;
  await vm.runInContext(`deletePerson('p1')`,ctx);
  assert.equal(rpcCalls[0][0],'delete_person');
  assert.equal(rpcCalls[0][1].p_person_id,'p1');
  assert.equal(vm.runInContext('route',ctx),'people');
  assert.equal(loaded,1);

  vm.runInContext(`route='event';selectedEventId='e1'`,ctx);
  await vm.runInContext(`deleteEvent('e1')`,ctx);
  assert.equal(rpcCalls[1][0],'delete_event');
  assert.equal(rpcCalls[1][1].p_event_id,'e1');
  assert.equal(vm.runInContext('route',ctx),'events');
  assert.equal(loaded,2);
  assert.equal(alerts.length,0);
  console.log('PASS: full backup download, route actions, confirmations, and safe delete RPC calls');
})().catch(error=>{console.error(error);process.exitCode=1});
