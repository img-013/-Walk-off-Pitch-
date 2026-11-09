const assert=require('node:assert/strict');
const db=require('../data/cards.json'),{EFFECTS}=require('../src/engine.js');
const ids=new Set(db.cards.map(c=>c.id));
assert.equal(ids.size,db.cards.length,'duplicate card IDs');
for(const c of db.cards){
 for(const field of ['id','name','description','effect_key','status','family','phase','slot','role'])assert.equal(typeof c[field],'string',`${c.id}.${field}`);
 assert.match(c.id,/^R\d{3}$/);assert.ok(['implemented','planned'].includes(c.status));
 assert.ok(['core','support'].includes(c.slot));assert.equal(c.stacking,'unique');
 assert.ok(Number.isInteger(c.price)&&c.price>0);assert.ok(Number.isInteger(c.reward_weight)&&c.reward_weight>0);
 for(const target of [...c.synergies,...c.tensions]){assert.ok(ids.has(target),`${c.id} bad relation ${target}`);assert.notEqual(target,c.id)}
 for(const ref of c.reference_ids)assert.ok(['BAL','PMD','SD','DD','DITD'].includes(ref));
 if(c.status==='implemented')assert.ok(EFFECTS.includes(c.effect_key),`${c.id} missing runtime handler`);
 else assert.ok(!EFFECTS.includes(c.effect_key),`${c.id} planned card accidentally active`);
 for(const value of Object.values(c.params))assert.ok(Number.isFinite(value)&&value>=0);
}
assert.equal(db.cards.filter(c=>c.status==='implemented').length,24);
assert.equal(db.cards.filter(c=>c.status==='planned').length,8);
assert.equal(db.rules.total_slots,db.rules.core_slots+db.rules.support_slots);
console.log('Validated 32 cards, stable IDs, references, relations and active handlers');
