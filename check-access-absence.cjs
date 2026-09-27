const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync('index.html','utf8');
const code=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1].replace(/init\(\);\s*$/,'');
const ctx=vm.createContext({location:{hash:''},document:{querySelector:()=>null},console});
vm.runInContext(code,ctx);
vm.runInContext(`
  session={user:{id:'owner',email:'admin@example.com'}};
  people=[
    {id:'old',name:'Anna',user_id:'owner'},
    {id:'recent',name:'Ben',user_id:'owner'},
    {id:'never',name:'Clara',user_id:'owner'}
  ];
  events=[
    {id:'e-old',title:'Früher',event_date:'2026-06-01',status:'Abgeschlossen',user_id:'owner'},
    {id:'e-new',title:'Neulich',event_date:'2026-09-10',status:'Abgeschlossen',user_id:'owner'}
  ];
  participations=[
    {id:'a-old',event_id:'e-old',person_id:'old',attended:true,response:'yes'},
    {id:'a-new',event_id:'e-new',person_id:'recent',attended:true,response:'yes'}
  ];
  absenceDays=60;
`,ctx);

vm.runInContext(`accessRole='viewer';route='dashboard'`,ctx);
assert.equal(vm.runInContext('isAdmin()',ctx),false);
const viewerLayout=vm.runInContext(`layout('<p>Inhalt</p>')`,ctx);
assert(viewerLayout.includes('Nur Lesen'));
assert(!viewerLayout.includes('onclick="openEvent()"'));
assert(!vm.runInContext('topbarAction()',ctx).includes('Zugriff'));

const absent=vm.runInContext('absenceCard()',ctx);
assert(absent.includes('Lange nicht gesehen'));
assert(absent.includes('Anna'));
assert(!absent.includes('Ben'));
assert(!absent.includes('Clara'));
assert(absent.includes('60 Tage'));

vm.runInContext(`accessRole='admin';workspaceMembers=[{email:'admin@example.com',role:'admin'},{email:'kollege@example.com',role:'viewer'}]`,ctx);
assert.equal(vm.runInContext('isAdmin()',ctx),true);
assert(vm.runInContext('topbarAction()',ctx).includes('Zugriff'));
const access=vm.runInContext('accessModal()',ctx);
assert(access.includes('kollege@example.com'));
assert(access.includes('Nur Lesen'));
assert(access.includes('removeViewerAt(1)'));
console.log('PASS: viewer mode, hidden write controls, access management, and long-absence report');
