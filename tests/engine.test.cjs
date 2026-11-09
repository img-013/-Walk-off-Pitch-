const test=require('node:test'),assert=require('node:assert/strict');
const db=require('../data/cards.json'),E=require('../src/engine.js');
const base=()=>({hp:30,maxHp:30,rules:[],pdice:[1,2,3],edice:[2,2,2],enemy:{id:'E002',hp:16,maxHp:16,gold:22},earlyLocked:[false,false,false],lastRerolled:3,battleLosses:0,battleCardGold:0});
const evaluate=(patch={})=>E.evaluate({...base(),...patch},db);
test('basic higher wins, absolute difference, tie zero',()=>{assert.equal(evaluate({pdice:[6,6,6]}).diff,12);assert.equal(evaluate().diff,0);assert.equal(evaluate({pdice:[1,1,1]}).lost,true)});
const cases=[
 ['R001',{pdice:[1,3,5]},r=>r.p===12],['R002',{pdice:[4,4,2]},r=>r.p===13],['R003',{pdice:[1,2,3]},r=>r.p===8],
 ['R004',{pdice:[1,2,2]},r=>r.diff===0&&r.lost],['R005',{hp:14},r=>r.p===8],['R006',{},r=>r.win&&r.diff===1],
 ['R007',{pdice:[1,1,1]},r=>r.win&&r.diff===3],['R008',{pdice:[6,2,1]},r=>r.p===6&&r.e===2],
 ['R009',{hp:10,pdice:[6,6,6]},r=>r.diff===15],['R010',{pdice:[3,3,3]},r=>r.gold===3],
 ['R011',{pdice:[2,4,6]},r=>r.p===15],['R012',{pdice:[1,2,3]},r=>r.p===8],
 ['R013',{pdice:[2,3,4]},r=>r.p===13],['R014',{pdice:[3,3,3]},r=>r.p===15],
 ['R015',{earlyLocked:[true,true,false]},r=>r.p===8],['R016',{lastRerolled:1},r=>r.p===8],
 ['R017',{},r=>r.p===9],['R018',{pdice:[1,1,1]},r=>r.diff===1],
 ['R019',{},r=>r.p===8],['R021',{},r=>r.p===10],
 ['R022',{battleLosses:4},r=>r.p===9],['R023',{pdice:[6,2,1]},r=>r.p===11],['R024',{pdice:[3,3,3]},r=>r.diff===5]
];
for(const [id,patch,expected]of cases)test(id+' effect and trace',()=>{const r=evaluate({rules:[id],...patch});assert.ok(expected(r));assert.ok(r.triggered.includes(id));assert.ok(r.events.some(e=>e.source===id))});
test('R020 battle reward',()=>assert.deepEqual(E.battleReward({...base(),rules:['R020']},db),{gold:30,cardId:'R020'}));
test('conditional cards do not fire on mismatches',()=>{
 const r=evaluate({pdice:[2,4,6],edice:[1,3,5],rules:['R001','R002','R005','R013','R016']});assert.equal(r.p,12);assert.equal(r.triggered.length,0);
 assert.equal(evaluate({rules:['R016'],lastRerolled:2}).p,6);
 assert.equal(evaluate({rules:['R017'],lastRerolled:0}).p,6);
 assert.equal(evaluate({rules:['R015']}).p,6);
});
test('paired bonuses trigger once, not per duplicate',()=>{const r=evaluate({pdice:[4,4,4],rules:['R002','R014','R024']});assert.equal(r.p,21);assert.equal(r.diff,17);assert.equal(r.triggered.filter(x=>x==='R002').length,1)});
test('all different and straight can combine',()=>assert.equal(evaluate({rules:['R003','R013']}).p,12));
test('reverse converts advantages and clamps at zero',()=>{const r=evaluate({rules:['R007','R012','R001'],pdice:[1,1,1]});assert.equal(r.p,0);assert.ok(r.win)});
test('exclusive cores and duplicate supports rejected',()=>{assert.throws(()=>evaluate({rules:['R007','R008']}));assert.throws(()=>evaluate({rules:['R001','R001']}))});
test('six supports and unknown cards rejected',()=>{assert.throws(()=>evaluate({rules:['R001','R002','R003','R004','R005','R006']}));assert.throws(()=>evaluate({rules:['R999']}))});
test('mirror is a nonmutating scoring copy',()=>{const s={...base(),enemy:{id:'E004',hp:28,maxHp:28},pdice:[6,2,1],edice:[1,2,3]};const before=JSON.stringify(s);const r=E.evaluate(s,db);assert.equal(r.e,11);assert.equal(JSON.stringify(s),before);assert.deepEqual(E.evaluate(s,db),r)});
test('boss even bonuses never alter faces and support reverse/max',()=>{const enemy={id:'B001',hp:15,maxHp:36,evenBonus:1};const patch={enemy,edice:[2,4,6]};assert.equal(evaluate(patch).e,15);assert.equal(evaluate({...patch,rules:['R008']}).e,6);assert.equal(evaluate({...patch,rules:['R007']}).e,9)});
test('single-die converts score bonuses, retains damage and tie rules',()=>{const r=evaluate({pdice:[6,6,6],edice:[6,6,6],rules:['R008','R023','R006','R024']});assert.equal(r.p,18);assert.equal(r.e,18);assert.equal(r.diff,4);assert.ok(r.triggered.includes('R023'));assert.ok(r.triggered.includes('R024'))});
test('single-die mirror is not a forced tie or unwinnable matchup',()=>{const r=evaluate({pdice:[6,5,4],edice:[1,2,3],enemy:{id:'E004',hp:24,maxHp:24},rules:['R008']});assert.equal(r.p,15);assert.equal(r.e,11);assert.ok(r.win)});
test('glass penalty applies after close shield and before low guard',()=>{const patch={pdice:[1,1,1],edice:[2,3,3],rules:['R021','R004']};const r=evaluate(patch);assert.equal(r.p,7);assert.equal(r.diff,2);assert.equal(evaluate({...patch,rules:[...patch.rules,'R018']}).diff,0)});
test('tie winner receives subsequent damage bonuses',()=>{assert.equal(evaluate({rules:['R006','R024'],pdice:[2,2,2]}).diff,3)});
test('round economy capped even after many wins',()=>{assert.equal(evaluate({pdice:[3,3,3],rules:['R010'],battleCardGold:8}).gold,1);assert.equal(evaluate({pdice:[3,3,3],rules:['R010'],battleCardGold:9}).gold,0)});
test('replacement slot rules',()=>{const get=id=>db.cards.find(c=>c.id===id);assert.deepEqual(E.replacementOptions(['R007'],get('R008'),db).options,['R007']);assert.equal(E.replacementOptions(['R001'],get('R002'),db).needsReplacement,false);assert.equal(E.replacementOptions(['R001','R002','R003','R004','R005'],get('R006'),db).options.length,5)});
test('seed generator deterministic with bounded outputs',()=>{let a=123,b=123;for(let i=0;i<1000;i++){const x=E.nextRandom(a),y=E.nextRandom(b);assert.deepEqual(x,y);assert.ok(x.value>=0&&x.value<1);a=x.seed;b=y.seed}});
test('all die combinations keep valid nonnegative finite damage',()=>{for(let a=1;a<=6;a++)for(let b=1;b<=6;b++)for(let c=1;c<=6;c++)for(const core of [[],['R007'],['R008']]){const r=evaluate({pdice:[a,b,c],rules:[...core,'R001','R002','R003','R004','R021']});assert.ok(Number.isInteger(r.diff)&&r.diff>=0);assert.ok(r.p>=0&&r.e>=0)}});
