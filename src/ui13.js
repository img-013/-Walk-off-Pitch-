const relicArt = {
  R007:[885,431,265,185], R008:[810,32,355,395],
  R073:[883,618,300,198], R074:[854,817,321,234],
  R075:[847,1053,310,187], R076:[870,1242,295,252],
  R077:[907,1495,236,255], R078:[873,1752,295,266]
};
const relicOrder = [...Object.keys(relicArt), null];

function supportCapacity(run = state) {
  const hasCore = run.rules.some(id => rules.find(card => card.id === id)?.slot === 'core');
  return run.noCore === true && !hasCore ? 6 : 5;
}

relicFragment = function(id) {
  const rect = relicArt[id];
  const size = id === 'R008' ? 1 : 0.72;
  return '<span class="relic-fragment" style="--relic-ratio:'+(rect[2]/rect[3])+';--relic-scale:'+size+';'+cropStyle(rect,2048,2048)+'"></span>';
};

function cycleRelic(step) {
  const index = relicOrder.indexOf(selectedCore);
  selectedCore = relicOrder[(index + step + relicOrder.length) % relicOrder.length];
  paintIntro();
}

const openRelics = chooseOpening;
chooseOpening = function() {
  openRelics();
  if (!skipPresentation) {
    selectedCore = relicOrder[0];
    paintIntro();
  }
};

paintIntro = function() {
  $('intro').className = 'screen intro-screen active archive-selection';
  $('introChoices').hidden = true;
  $('introNext').hidden = true;
  $('introBlackout').hidden = true;
  $('coreDetail').hidden = false;
  const card = rules.find(item => item.id === selectedCore);
  $('relicDisplay').innerHTML = card ? relicFragment(card.id) : '<span class="empty-relic" aria-hidden="true">∅</span>';
  $('coreDetailName').textContent = card?.name || '无戒律';
  $('coreDetailText').textContent = card?.text || '按基础规则结算。本局可以装备六条规则。';
  $('confirmCore').disabled = false;
  $('confirmCore').textContent = card ? '确认戒律 →' : '无戒律启程 →';
};

confirmCore = function() { selectIntroCore(selectedCore); };
selectIntroCore = function(id) {
  if (!introRunning || (id !== null && !relicArt[id])) return;
  state.noCore = id === null;
  state.rules = id ? [id] : [];
  recordAction('opening_core',{id});
  finishIntro();
};

welcome[0] = ['命运本身','欢迎来到拉斯科尔。每一条戒律，都会改变赌局的秩序。'];
finishIntro = function() {
  if (!introRunning) return;
  introRunning = false;
  show('map');
  tellStories(welcome, () => {
    offerRules(false, () => {
      state.tutorial = runNeedsTutorial ? 'map' : 'done';
      renderMap();
      saveCheckpoint();
    });
  });
};

const renderFiveSlots = renderRules;
renderRules = function() {
  renderFiveSlots();
  const six = supportCapacity() === 6;
  const card = rules.find(item => item.id === state.rules[5]);
  $('ruleCount').textContent = state.rules.filter(id => rules.find(item => item.id === id)?.slot === 'support').length+' / '+supportCapacity();
  if (!six) {
    $('battleCore').disabled = !state.rules.some(id => relicArt[id]);
    return;
  }
  const slot = $('battleCore');
  slot.disabled = !card;
  slot.innerHTML = card ? '<small>'+card.id+'</small><b>'+card.name+'</b><span>'+card.text+'</span>' : '';
  slot.setAttribute('aria-label',card ? '查看 '+card.name : '第六规则位');
  slot.onclick = () => { if (card) inspectCard(card.id); };
};

const textCard = cardHTML;
cardHTML = function(card) {
  return textCard(card).replace(/<div class="archive-card-art">.*?<\/div>/,'');
};

pipHTML = function(value) {
  const x = [287,1041,1797][(value-1)%3];
  const y = value <= 3 ? 168 : 789;
  return '<span class="dice-face-art" aria-hidden="true" style="'+cropStyle([x,y,487,476],2560,1440)+'"></span>';
};

function renderSharedHealth(result) {
  if (!state.enemy) return;
  const player = state.hp/state.maxHp;
  const enemy = state.enemy.hp/state.enemy.maxHp;
  const share = Math.max(0,Math.min(100,100*player));
  const playerShield = result?.playerShield ?? (state.carryShield || 0)+(state.enemyMemory?.thriftRound === state.roundNumber ? 2 : 0);
  const enemyShield = result?.enemyShield ?? EnemySystem.guard(state);
  $('playerShare').style.width = share+'%';
  $('playerShield').style.width = Math.min(share,100*playerShield/state.maxHp)+'%';
  $('enemyShield').style.width = Math.min(100-share,100*enemyShield/state.enemy.maxHp)+'%';
  $('sharedHealth').setAttribute('aria-label','双方生命：'+state.hp+' / '+state.enemy.hp+'。护盾：'+playerShield+' / '+enemyShield);
  $('sharedHealth').title = '己方护盾 '+playerShield+' · 敌方护盾 '+enemyShield;
}
const renderBattleWithArtwork = renderBattle;
renderBattle = function() {
  renderBattleWithArtwork();
  renderSharedHealth(state.roll === 3 && !busy ? evaluate() : undefined);
};

rulebookPages.base = rulebookPages.base.replace('同时装备最多 5 张被动牌和 1 张核心牌','选用戒律时可装备 5 条规则，无戒律时可装备 6 条规则').replace('开局选核心与方向','开局选择戒律或无戒律').replace('另外五个位置放置自动触发的规则卡','其余位置放置自动触发的规则卡').replace('开场可跳过过场，新手对白也可跳过','首局新手对白可跳过');
