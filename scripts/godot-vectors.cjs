const fs=require('fs'),path=require('path');const E=require('../src/engine.js'),ES=require('../src/enemy-system.js'),db=require('../data/cards.json'),enemies=require('../data/enemies.json');
const cases=[];let seed=734;const r=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);const dice=()=>Array.from({length:3},()=>1+Math.floor(r()*6));
const ids=Object.keys(enemies);const loadouts=db.cards.map(c=>[c.id]);
for(const core of ['',...db.cards.filter(c=>c.slot==='core').map(c=>c.id)])for(const extras of [['R011','R034','R067'],['R011','R034','R066'],['R001','R027','R002'],['R037','R068','R080'],['R017','R050','R069'],['R024','R052','R062']])loadouts.push([core,...extras].filter(Boolean));
for(const rules of loadouts)for(let i=0;i<8;i++){
 const enemy=structuredClone(enemies[ids[(cases.length+i)%ids.length]]);enemy.id=ids[(cases.length+i)%ids.length];enemy.maxHp=enemy.hp;if(i%2)enemy.hp=Math.floor(enemy.hp/2);
 let s={hp:[7,15,25,4][i%4],maxHp:30,gold:30,rules,enemy,pdice:i===0?[2,2,2]:i===1?[1,2,3]:i===2?[6,6,6]:dice(),edice:dice().slice(0,enemy.dice),locked:[i%2===0,true,i%3===0],earlyLocked:[i%2===0,false,i%3===0],lastRerollMask:[true,i%2===0,true],lastRerolled:i%4,enemyKept:i%3,roundNumber:i+1,battleLosses:i%4,carryAdv:i%4,carryShield:i%3,openingAdv:2,openingDebt:1,faceChanges:i%3,rerollsAfterFirst:i,battleCardGold:0,battleHealing:0,cardGold:{},cardHealing:{},used:{},fateDebt:2,previousLockSignature:'0:0|1:0|2:0',enemyMemory:{schools:{parity:3},streak:2,pattern:'对子',parity:0,suppress:i%3===0?'parity':null,triggers:3,tax:'refuse',wagerRound:i===2?3:0}};
 s=ES.prepare(s);const expected=E.evaluate(s,db);s.enemyIntent.suppress??='';s.enemyIntent.field??='';s.enemyIntent.seal??=-1;s.enemyMemory.suppress??='';
 cases.push({name:rules.join('+')+'/'+i,state:s,expected:Object.fromEntries(['p','e','diff','win','lost','gold','heal','selfCost','nextAdv','nextShield','generatedGold','playerShield','enemyShield'].map(k=>[k,expected[k]]))});
}
fs.mkdirSync(path.join(__dirname,'../godot/tests'),{recursive:true});fs.writeFileSync(path.join(__dirname,'../godot/tests/parity.json'),JSON.stringify(cases));console.log(cases.length+' engine parity fixtures exported');
