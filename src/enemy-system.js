/* Pure, telegraphed enemy mechanics. No random draws or UI side effects. */
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.EnemySystem=api;})(typeof globalThis!=='undefined'?globalThis:this,()=>{
'use strict';
const branches={pressure:'数值压迫',dice:'骰子干扰',pattern:'牌型限制',tempo:'节奏控制',resource:'资源消耗',counter:'规则反制',risk:'风险博弈',field:'战场变化'};
const descriptions={learn:'双骰入门，无特殊限制',grow:'每回合增长1伤害，最多3；只在敌方胜出时生效',seal:'偶数回合指定一骰不能锁定，其他两骰照常',repeat:'沿用上一回合牌型时，敌方获得2护盾',charge:'每4回合蓄力爆发，敌方胜出额外4伤害',tax:'战前可付6金币解除强化；拒付则敌方胜出+1伤害，胜利额外8金币',inspect:'每3回合检查此前触发最多的流派，下一回合该流派每张得分牌少1优势',wager:'偶数回合可自愿加注，双方最终伤害翻倍；赢下该回合额外2金币',tide:'奇数回合双方低点骰提供优势，偶数回合高点骰提供优势；不改变主戒律',streak:'玩家连胜令敌方胜出伤害增加，最多3；玩家失利清零',mirror:'复制玩家最高骰，仅改变计分副本',even:'半血后偶数骰为敌方提供优势',scar:'第3回合起，玩家三骰全重投则敌方获得2护盾',parity:'上一回合多数奇偶重复时，敌方获得2护盾',straight:'每3回合预告防顺子，玩家顺子时敌方获得3护盾',thrift:'每3回合可支付4金币取得2护盾；拒绝无额外惩罚',alternating:'奇数回合敌方有2护盾，偶数回合敌方胜出+2伤害',lockhunt:'玩家锁满三骰时敌方胜出+2伤害',echo:'上一回合触发至少3张辅助牌时，下一回合敌方有2护盾',mercy:'玩家本回合无锁骰时，双方胜出伤害各减2'};
const signature=a=>{const unique=new Set(a).size;return unique===1?'三同':unique===2?'对子':Math.max(...a)-Math.min(...a)===2?'顺子':'散点';};
function dominant(s){return Object.entries(s.enemyMemory?.schools||{}).sort((a,b)=>b[1]-a[1]||a[0].localeCompare(b[0]))[0]?.[0]||null;}
function intent(s){const e=s.enemy||{},n=s.roundNumber||1,m=s.enemyMemory||{},tags=e.mechanics||[],out={round:n,seal:null,attack:0,guard:0,suppress:null,field:null,tax:false,wager:false,thrift:false,repeat:false,parity:false,straight:false,mirror:false,even:false,scar:false,lockhunt:false,mercy:false,lines:[]};
 const active=e.rank==='boss'?(e.phases?.[e.hp<=e.maxHp/2?1:0]||tags):tags;
 for(const tag of active){switch(tag){
 case'grow':out.attack+=Math.min(3,n-1);break;
 case'seal':if(n%2===0)out.seal=(n+e.chapter)%3;break;
 case'repeat':out.repeat=true;break;
 case'charge':if(n%4===0)out.attack+=4;break;
 case'tax':out.tax=true;if(m.tax==='refuse')out.attack++;break;
 case'inspect':out.suppress=m.suppress||null;break;
 case'wager':out.wager=n%2===0;break;
 case'tide':out.field=n%2?'low':'high';break;
 case'streak':out.attack+=Math.min(3,m.streak||0);break;
 case'mirror':out.mirror=true;break;
 case'even':out.even=e.hp<=e.maxHp/2;break;
 case'scar':out.scar=n>=3;break;
 case'parity':out.parity=true;break;
 case'straight':out.straight=n%3===0;break;
 case'thrift':out.thrift=n%3===0;break;
 case'alternating':if(n%2)out.guard+=2;else out.attack+=2;break;
 case'lockhunt':out.lockhunt=true;break;
 case'echo':if((m.triggers||0)>=3)out.guard+=2;break;
 case'mercy':out.mercy=true;break;
 }
 }
 // Debt adds a visible, bounded tempo condition, never a hidden HP multiplier.
 if(e.chapter===3&&(s.fateDebt||0)>=2&&n%3===0){out.attack++;out.lines.push('命运债务：本回合敌方胜出伤害+1');}
 out.lines.push('回合'+n+(e.rank==='boss'?' · 阶段'+(e.hp<=e.maxHp/2?'Ⅱ':'Ⅰ'):''));
 if(out.seal!==null)out.lines.push('第'+(out.seal+1)+'骰本回合无法锁定');
 if(out.attack)out.lines.push('敌方胜出伤害+'+out.attack);
 if(out.guard)out.lines.push('敌方护盾'+out.guard);
 if(out.repeat)out.lines.push('重复'+(m.pattern||'上回合牌型')+'：敌方护盾+2');
 if(out.parity)out.lines.push('重复多数'+(m.parity===1?'奇':m.parity===0?'偶':'奇偶')+'：敌方护盾+2');
 if(out.straight)out.lines.push('本回合顺子：敌方护盾+3');
 if(out.suppress)out.lines.push('抑制'+({parity:'奇偶',combo:'组合',high:'高点',low:'低点',lock:'锁骰',reroll:'重投',risk:'险境',face:'改骰'}[out.suppress]||out.suppress)+'：每张得分牌优势-1（最低0）');
 if(out.field)out.lines.push('双方每枚'+(out.field==='low'?'1–2':'5–6')+'骰提供1优势');
 if(out.wager)out.lines.push(m.wagerRound===n?'本回合已加注：双方伤害×2':'本回合可加注或按原规则继续');
 if(out.thrift)out.lines.push(m.thriftRound===n?'已购买本回合2护盾':'可付4金币购买本回合2护盾');
 if(out.mirror)out.lines.push('结算复制你的最高骰');
 if(out.even)out.lines.push('敌方偶数骰+1优势');
 if(out.scar)out.lines.push('末掷全重投：敌方护盾+2');
 if(out.lockhunt)out.lines.push('锁满三骰：敌方胜出伤害+2');
 if(out.mercy)out.lines.push('零锁骰：双方伤害-2');
 if(active.includes('charge'))out.lines.push('蓄力爆发：第'+(Math.floor((n-1)/4)*4+4)+'回合');
 if(active.includes('inspect'))out.lines.push(n%3===0?'本回合后审查，下一回合生效':'每3回合结束审查一次');
 if(active.includes('learn'))out.lines.push('双骰练习：保留高点（逆点主戒律保留低点）');
 return out;
}
function begin(s){return{...s,enemyMemory:{streak:0,schools:{},suppress:null},enemyIntent:null};}
function prepare(s){const next={...s};next.enemyIntent=intent(next);return next;}
function canLock(s,i){return s.enemyIntent?.seal!==i;}
function choose(s,kind){const n=s.roundNumber||1,m={...s.enemyMemory},i=s.enemyIntent||intent(s);let cost=0;
 if(kind==='pay'||kind==='refuse'){if(!i.tax||m.tax||s.roll!==0)throw Error('Tax unavailable');cost=kind==='pay'?6:0;m.tax=kind;}
 else if(kind==='wager'){if(!i.wager||s.roll!==0||m.wagerRound===n)throw Error('Wager unavailable');m.wagerRound=n;}
 else if(kind==='thrift'){if(!i.thrift||s.roll!==0||m.thriftRound===n)throw Error('Shield purchase unavailable');cost=4;m.thriftRound=n;}
 else throw Error('Unknown enemy choice');
 if(s.gold<cost)throw Error('Cannot afford enemy choice');return{state:prepare({...s,gold:s.gold-cost,enemyMemory:m}),cost};
}
function after(s,r,db){const m={...s.enemyMemory,schools:{...s.enemyMemory?.schools}},n=s.roundNumber||1;m.pattern=signature(s.pdice);m.parity=s.pdice.filter(v=>v%2).length>=2?1:0;m.streak=r.win?(m.streak||0)+1:r.lost?0:m.streak||0;m.triggers=0;
 for(const id of r.triggered){const c=db.cards.find(c=>c.id===id);if(c?.slot==='support'){m.triggers++;if(c.school)m.schools[c.school]=(m.schools[c.school]||0)+1;}}
 m.suppress=n%3===0?dominant({enemyMemory:m}):null;return m;
}
function guard(s){const i=s.enemyIntent||{},m=s.enemyMemory||{};return(i.guard||0)+(i.repeat&&m.pattern===signature(s.pdice)?2:0)+(i.parity&&m.parity===(s.pdice.filter(v=>v%2).length>=2?1:0)?2:0)+(i.straight&&signature(s.pdice)==='顺子'?3:0)+(i.scar&&s.lastRerolled===3?2:0);}
function threat(e){const tags=[...new Set([...(e.mechanics||[]),...(e.phases||[]).flat()])],v=[Math.min(1,e.hp/60),Math.min(1,(e.dice/3*.35+tags.filter(t=>['grow','charge','streak','alternating','lockhunt','wager'].includes(t)).length*.2)),tags.includes('seal')?1/3:0,Math.min(1,tags.filter(t=>['repeat','inspect','parity','straight','mirror','echo'].includes(t)).length*.25),tags.some(t=>['tax','thrift','wager'].includes(t))?.3:0];return{components:v,value:+v.reduce((a,b,i)=>a+b*[.2,.3,.2,.2,.1][i],0).toFixed(3)};}
return{branches,descriptions,signature,intent,begin,prepare,canLock,choose,after,guard,threat};
});
