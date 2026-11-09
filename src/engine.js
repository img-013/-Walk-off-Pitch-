/* Pure settlement engine: no DOM, timers, global run state or random sampling. */
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.WalkOffEngine=api;})(typeof globalThis!=='undefined'?globalThis:this,()=>{
  'use strict';
  const sum=a=>a.reduce((a,b)=>a+b,0);
  const EFFECTS=['odd_bonus','pair_bonus','unique_bonus','close_guard','low_hp','tie_win','low_wins','max_only','desperate','all_odd_gold','even_bonus','small_bonus','straight_bonus','triple_bonus','early_lock','one_reroll','all_reroll','low_guard','enemy_even','battle_gold','glass_pact','loss_growth','six_bonus','pair_damage'];
  function evaluate(state,database){
    const byId=new Map(database.cards.map(c=>[c.id,c]));
    const cards=state.rules.map(id=>byId.get(id));
    if(cards.some(c=>!c||c.status!=='implemented'||!EFFECTS.includes(c.effect_key)))throw Error('Unknown or unimplemented equipped card');
    if(new Set(state.rules).size!==state.rules.length||cards.filter(c=>c.slot==='core').length>1||cards.filter(c=>c.slot==='support').length>5)throw Error('Illegal loadout');
    if(state.pdice.length!==3||!state.edice.length||[...state.pdice,...state.edice].some(v=>!Number.isInteger(v)||v<1||v>6))throw Error('Invalid physical die');
    const has=fx=>cards.find(c=>c.effect_key===fx),raw=[...state.pdice],enemy=[...state.edice],lines=[],events=[],triggered=[];
    const counts={};raw.forEach(v=>counts[v]=(counts[v]||0)+1);
    const pair=Object.values(counts).some(n=>n>=2),triple=Object.values(counts).some(n=>n===3),unique=new Set(raw).size===3;
    const reversed=!!has('low_wins'),single=!!has('max_only');
    function event(card,phase,amount,text){if(card&&!triggered.includes(card.id))triggered.push(card.id);events.push({source:card?.id||'system',phase,amount,text});lines.push(text)}
    if(state.enemy.id==='E004'){enemy[0]=Math.max(...raw);event(null,'enemy_copy',enemy[0],'镜面赌徒：计分时复制最高骰 '+enemy[0])}
    let p=single?Math.max(...raw):sum(raw),e=single?Math.max(...enemy):sum(enemy);
    event(has('max_only'),'base',0,`${single?'最高单骰':'基础总点数'} ${p} : ${e}`);
    if(single&&p===e){p=sum(raw);e=sum(enemy);event(has('max_only'),'base',0,`最高骰相同，改比原始总和 ${p} : ${e}`)}
    if(single)event(null,'score',0,'单骰决胜：跳过双方计分加成，伤害与经济规则保留');
    for(const c of cards){if(single)continue;const a=c.params.amount||0;let bonus=0;
      switch(c.effect_key){
        case 'odd_bonus':bonus=raw.filter(v=>v%2).length*a;break;
        case 'even_bonus':bonus=raw.filter(v=>v%2===0).length*a;break;
        case 'pair_bonus':bonus=pair?a:0;break;
        case 'unique_bonus':bonus=unique?a:0;break;
        case 'low_hp':bonus=state.hp<state.maxHp/2?a:0;break;
        case 'small_bonus':bonus=raw.filter(v=>v<=c.params.threshold).length*a;break;
        case 'straight_bonus':bonus=unique&&Math.max(...raw)-Math.min(...raw)===2?a:0;break;
        case 'triple_bonus':bonus=triple?a:0;break;
        case 'early_lock':bonus=(state.earlyLocked||[]).filter(Boolean).length*a;break;
        case 'one_reroll':bonus=state.lastRerolled===1?a:0;break;
        case 'all_reroll':bonus=state.lastRerolled===3?a:0;break;
        case 'enemy_even':bonus=state.edice.filter(v=>v%2===0).length>=c.params.count?a:0;break;
        case 'glass_pact':bonus=a;break;
        case 'loss_growth':bonus=Math.min(c.params.cap,(state.battleLosses||0)*a);break;
        case 'six_bonus':bonus=raw.includes(6)?a:0;break;
      }
      if(bonus){const before=p;p=Math.max(0,p+(reversed?-bonus:bonus));event(c,'score',p-before,`${c.name}：${reversed?'减':'加'} ${Math.abs(p-before)}（优势 ${bonus}）`)}
    }
    if(!single&&state.enemy.id==='B001'&&state.enemy.hp<=state.enemy.maxHp/2){
      // In reverse mode the same enemy advantage is subtracted, never added.
      const adjusted=enemy.map(v=>v+(v%2===0?(state.enemy.evenBonus??1):0));const delta=sum(adjusted)-sum(enemy);
      e=Math.max(0,e+(reversed?-delta:delta));event(null,'enemy_bonus',delta,'偶数共鸣：敌方 '+delta+' 点优势');
    }
    let diff=Math.abs(p-e),win=reversed?p<e:p>e,tie=p===e;
    if(reversed)event(has('low_wins'),'compare',0,'反向赌局：低者胜');
    if(tie&&has('tie_win')){win=true;diff=has('tie_win').params.amount;event(has('tie_win'),'compare',diff,'庄家通吃：平局判胜，基础伤害 '+diff)}
    const lost=!win&&!tie;let damage=diff;
    if(win){for(const c of cards){let extra=0;if(c.effect_key==='desperate'&&state.hp<=c.params.hp)extra=c.params.amount;if(c.effect_key==='pair_damage'&&pair)extra=c.params.amount;if(extra){damage+=extra;event(c,'damage',extra,c.name+'：伤害 +'+extra)}}}
    if(lost){
      const close=has('close_guard'),glass=has('glass_pact'),guard=has('low_guard');
      if(close&&diff===close.params.threshold){damage=0;event(close,'damage',-diff,'差一点：基础差值免伤')}
      if(glass){damage+=glass.params.penalty;event(glass,'damage',glass.params.penalty,'玻璃誓约：风险伤害 +'+glass.params.penalty)}
      if(guard&&sum(raw)<=guard.params.threshold){const reduction=Math.min(damage,guard.params.amount);damage-=reduction;if(reduction)event(guard,'damage',-reduction,'低潮护符：减伤 '+reduction)}
    }
    let gold=0;const econ=has('all_odd_gold');
    if(win&&econ&&raw.every(v=>v%2)){gold=Math.min(econ.params.amount,Math.max(0,econ.params.cap-(state.battleCardGold||0)));if(gold)event(econ,'economy',gold,'拒绝对称：金币 +'+gold)}
    return {p,e,diff:damage,baseDifference:diff,win,lost,tie,gold,triggered,events,lines};
  }
  function battleReward(state,database){const card=database.cards.find(c=>state.rules.includes(c.id)&&c.status==='implemented'&&c.effect_key==='battle_gold');return{gold:state.enemy.gold+(card?.params.amount||0),cardId:card?.id||null}}
  function replacementOptions(ids,newCard,database){const byId=new Map(database.cards.map(c=>[c.id,c]));if(ids.includes(newCard.id))return{duplicate:true,needsReplacement:false,options:[]};const same=ids.filter(id=>byId.get(id)?.slot===newCard.slot);const cap=newCard.slot==='core'?1:5;return{duplicate:false,needsReplacement:same.length>=cap,options:same.length>=cap?same:[]}}
  function nextRandom(seed){let value=(seed+0x6D2B79F5)>>>0,t=value;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return{seed:value,value:((t^(t>>>14))>>>0)/4294967296}}
  return {evaluate,battleReward,replacementOptions,nextRandom,EFFECTS};
});
