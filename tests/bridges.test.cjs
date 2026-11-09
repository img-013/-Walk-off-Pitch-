const test=require('node:test'),assert=require('node:assert/strict'),E=require('../src/engine'),db=require('../data/cards.json');
const state=(rules,patch={})=>({rules,hp:14,maxHp:30,gold:20,rng:7,roll:2,pdice:[2,4,6],edice:[2,2,2],enemy:{id:'E002',hp:30,maxHp:30,gold:22},locked:[false,false,false],earlyLocked:[false,false,false],lastRerolled:3,lastRerollMask:[true,true,true],...patch});
const fixtures=[
['parity+reroll','R019',['R019'],{}],
['combo+parity','R027',['R011','R027','R002'],{pdice:[2,2,4]}],
['high+risk','R027',['R023','R027','R005'],{}],
['lock+low','R027',['R012','R027','R015'],{locked:[true,true,false],earlyLocked:[true,true,false],lastRerolled:1,lastRerollMask:[false,false,true]}],
['high+reroll','R027',['R023','R027','R017'],{}],
['low+risk','R028',['R028'],{pdice:[1,2,3],edice:[6,6,6]}],
['lock+parity','R064',['R064'],{pdice:[3,3,4],locked:[true,true,false],lastRerolled:1,lastRerollMask:[false,false,true]}],
['face+parity','R066',['R011','R034','R066'],{faceChanges:1}],
['reroll+risk','R069',['R069'],{}],
['high+lock','R080',['R023','R080'],{locked:[false,false,true],lastRerolled:2,lastRerollMask:[true,true,false]}],
['combo+face','R071',['R071'],{pdice:[2,2,6],faceChanges:1}],
['low+reroll','R079',['R079'],{}]
];
for(const[edge,source,rules,patch]of fixtures)test('mechanical bridge '+edge,()=>{assert.ok(db.cards.find(c=>c.id===source).bridge_pairs.some(p=>[...p].sort().join('+')===edge));assert.ok(E.evaluate(state(rules,patch),db).triggered.includes(source));});
test('lock + reroll forces previously retained enemy maximum',()=>{const s=state(['R029'],{locked:[true,false,false],edice:[6,5,4]});const r=E.resolveRoll(s,db);assert.equal(r.em[0],true);assert.equal(r.em[1],false);assert.ok(r.rollEvents.includes('R029'));});
test('face + lock changes held face, exposing high and low choices',()=>{const s=state(['R070'],{pdice:[1,6,3],locked:[true,true,false],earlyLocked:[true,true,false]});const r=E.resolveRoll(s,db);assert.deepEqual(r.pdice.slice(0,2),[6,1]);assert.equal(r.faceChanges,2);});
test('14 distinct bridge pairs and parity-lock has three paths',()=>{const edges=new Set(db.cards.flatMap(c=>c.bridge_pairs.map(p=>[...p].sort().join('+'))));assert.equal(edges.size,14);assert.equal(db.cards.filter(c=>c.bridge_pairs.some(p=>[...p].sort().join('+')==='lock+parity')).length,3);});
