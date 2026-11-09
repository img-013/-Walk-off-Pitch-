const {spawnSync}=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.join(__dirname,'..'));
const commands=[['scripts/validate.cjs'],['scripts/build.cjs'],['--test',...fs.readdirSync('tests').filter(f=>f.endsWith('.test.cjs')).map(f=>'tests/'+f)]];
for(const args of commands){const r=spawnSync(process.execPath,args,{stdio:'inherit'});if(r.error)throw r.error;if(r.status!==0)process.exit(r.status||1)}
