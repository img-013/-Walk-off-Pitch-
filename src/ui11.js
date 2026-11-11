// Artwork-led presentation. No changes to rolls, card effects or enemy settlement.
const CORE_ICONS={R007:{name:'倒悬天平',col:0,row:0},R008:{name:'沙漏',col:1,row:0},R073:{name:'齿轮',col:2,row:0},R074:{name:'天平',col:3,row:0},R075:{name:'拼图',col:0,row:1},R076:{name:'怀表',col:1,row:1},R077:{name:'魔镜',col:2,row:1},R078:{name:'钱袋',col:3,row:1}};
function coreIcon(id){const icon=CORE_ICONS[id];return icon?'<span aria-hidden="true" class="core-object" style="background-position:'+(icon.col*100/3)+'% '+icon.row*100+'%"></span>':'';}
let tutorialSeen=false,runNeedsTutorial=true,hoverCore=null,selectedCore=null;
try{tutorialSeen=!previewRun&&localStorage.getItem('walkoffpitch-tutorial-seen')==='1';}catch{}
const newGame11=newGame;
newGame=function(options={}){runNeedsTutorial=!tutorialSeen;tutorialSeen=true;if(!previewRun)try{localStorage.setItem('walkoffpitch-tutorial-seen','1');}catch{}hoverCore=null;selectedCore=null;newGame11(options);};
const stories11=tellStories;
tellStories=function(pages,after){if(!runNeedsTutorial){after();return;}stories11(pages,after);};
const chooseOpening11=chooseOpening;
chooseOpening=function(){chooseOpening11();if(!skipPresentation){introStep=-1;paintIntro();}};
paintIntro=function(){
 const selecting=introStep===2,black=introStep<0||introStep===4;
 $('intro').className='screen intro-screen active '+(selecting?'choose-relic':black?'comic-black':'comic-page');
 $('introArtwork').className='intro-art';
 $('introArtwork').innerHTML=black?'':selecting?'<img class="chest-scene" src="'+PITCH_MEDIA.chest+'" alt="海浪中的行李箱与白鲸">':introStep<2?'<img class="comic-image '+(introStep===0?'first-panel':'complete-panels')+'" src="'+PITCH_MEDIA.comic+'" alt="'+(introStep===0?'船驶入巨浪':'白鲸在船边现身')+'">':coverSvg(PitchArt.scene(3));
 $('introHeading').textContent=selecting?'抓住你的戒律':introStep===3?'拉斯科尔':'';
 $('introCaption').textContent=selecting?'悬停查看 · 点击选中 · 确认带走':introStep===3?'你被浪潮抛上岸。远处，赌城仍然亮着灯。':'';
 $('introIndex').textContent=selecting?'选择主戒律':introStep===3?'抵达赌城':'序章 · 白鲸';
 $('introChoices').replaceChildren();$('introChoices').hidden=!selecting;
 if(selecting){for(const [id,icon]of Object.entries(CORE_ICONS)){const c=rules.find(c=>c.id===id),b=document.createElement('button');b.className='relic-choice relic-'+id+(selectedCore===id?' selected':'');b.innerHTML=coreIcon(id)+'<span class="relic-label">'+icon.name+'</span>';b.setAttribute('aria-label','选择主戒律 '+c.name+'。'+c.text);b.setAttribute('aria-pressed',String(selectedCore===id));b.onmouseenter=()=>previewCore(id);b.onfocus=()=>previewCore(id);b.onmouseleave=()=>previewCore(selectedCore);b.onclick=()=>{selectedCore=id;paintIntro();previewCore(id);};$('introChoices').appendChild(b);}}
 $('coreDetail').hidden=!selecting;previewCore(selectedCore||hoverCore);
 $('introNext').hidden=selecting;$('introNext').textContent=introStep<0?'点击展开第一格 →':introStep===0?'点击展开完整画面 →':introStep===1?'抓住散落的行李 →':introStep===3?'随浪上岸 →':'继续 →';
 $('introBlackout').hidden=introStep!==4;if(introStep===4)$('introBlackout').focus();
 $('introArtwork').onclick=()=>{if(introStep<2)nextIntro();};
};
function previewCore(id){hoverCore=id;const c=rules.find(c=>c.id===id);$('coreDetailName').textContent=c?CORE_ICONS[id].name+' · '+c.name:'八件遗物，只能带走一件';$('coreDetailText').textContent=c?c.text:'把鼠标移到物品上查看戒律；点击后高亮选中。';$('confirmCore').disabled=!selectedCore;$('confirmCore').textContent=selectedCore?'带走「'+rules.find(c=>c.id===selectedCore).name+'」':'先选择一件遗物';}
function confirmCore(){if(selectedCore)selectIntroCore(selectedCore);}
const renderRules11=renderRules;
renderRules=function(){const core=rules.find(c=>state.rules.includes(c.id)&&c.slot==='core'),support=state.rules.map(id=>rules.find(c=>c.id===id)).filter(c=>c.slot==='support');$('ruleCount').textContent=support.length+' / 5';$('ruleGrid').innerHTML=Array.from({length:5},(_,i)=>{const c=support[i];return c?'<button class="rule-card frame-card '+(state.triggered.includes(c.id)?'trigger':'')+'" data-inspect-card="'+c.id+'" id="card-'+c.id+'" aria-label="查看 '+c.name+'"><b>'+c.name+'</b><span>'+c.text+'</span></button>':'<div class="frame-card empty-slot" aria-hidden="true"></div>';}).join('');$('battleCore').innerHTML=core?coreIcon(core.id)+'<span>'+core.name+'</span>':'<span>未选择戒律</span>';$('battleCore').setAttribute('aria-label',core?'查看主戒律 '+core.name:'主戒律');$('battleCore').onclick=()=>{if(core)inspectCard(core.id);};};
function showEnemyDetails(){if(state.enemy)modal(state.enemy.name,state.enemy.desc+'<hr>'+(state.enemyIntent?.lines||[]).join('<br>'),[['返回赌局',()=>{}]]);}
function showBattleDetails(){modal('结算明细',state.lastDiagnostic?.result?.lines.join('<br>')||'三次投掷后显示结算明细。',[['返回赌局',()=>{}]]);}
const renderMap11=renderMap;
renderMap=function(){renderMap11();requestAnimationFrame(()=>{const canvas=$('mapViewport'),target=document.querySelector?.('.map-node.available');if(canvas&&target){canvas.scrollTop=Math.max(0,target.offsetTop-canvas.clientHeight*.7);}});};
const show11=show;
show=function(id){show11(id);document.body?.setAttribute('data-screen',id);};
rulebookPages.map=rulebookPages.map.replace('点击地图下方的遭遇情报也可进入节点。','地图在右侧独立上下滚动。沿连线选择节点，悬停节点可读敌人信息。');

const openRulebook11=openRulebook;
openRulebook=function(page='base'){openRulebook11(page);for(const [label,action] of [['检视六面骰',openDiceInspector],['重新启程',restartPrompt]]){const b=document.createElement('button');b.className='choice';b.textContent=label;b.onclick=()=>{$('overlay').classList.remove('show');action();};$('modalChoices').appendChild(b);}};
showBattleDetails=function(){modal('结算明细',(state.lastDiagnostic?.result?.lines.join('<br>')||'三次投掷后显示结算明细。')+'<hr><h3>战斗记录</h3>'+($('log').innerHTML||'暂无记录。'),[['返回赌局',()=>{}],['导出本次结算诊断',exportDiagnostic]]);};
rulebookPages.base=rulebookPages.base.replace('v0.8 使用独立存档，不读取 v0.6 存档。','v0.11 使用独立地图存档，旧版进度保留但不自动转换。');
