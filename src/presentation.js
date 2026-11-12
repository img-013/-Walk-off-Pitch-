// Presentation and authored onboarding. Rules and RNG remain in engine.js.
let introStep=0,introRunning=false,storyState=null,skipPresentation=false;
const coverSvg=markup=>markup.replace('<svg ','<svg preserveAspectRatio="xMidYMid slice" ');
const opening80=chooseOpening,newGame80=newGame,chooseNode80=chooseNode,startBattle80=startBattle;
const rollDice80=rollDice,settle80=settle;
rollDice=async function(){if(storyState||introRunning)return;return rollDice80();};
settle=async function(){if(storyState||introRunning)return;return settle80();};
const reducedMotion=()=>!!window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
let quickMotion=false;
window.PitchMotion={duration:ms=>reducedMotion()?0:quickMotion?Math.round(ms*.4):ms};
function toggleMotion(){quickMotion=!quickMotion;document.documentElement?.classList.toggle('quick-motion',quickMotion);$('motionBtn').textContent=quickMotion?'动效 ×2.5':'动效 ×1';$('motionBtn').setAttribute('aria-pressed',String(quickMotion));}
newGame=function(options={}){skipPresentation=options?.skipIntro===true;introRunning=false;storyState=null;$('storyOverlay').hidden=true;newGame80();};
chooseOpening=function(){if(skipPresentation){opening80();return}state.tutorial='opening';introRunning=true;introStep=0;paintIntro();show('intro');};
const introTitles=['海面之下','它看见了你','抓住你的戒律','拉斯科尔'];
const introLines=['驶入赌城的船，从来没有平静的航程。','那只血红的眼睛，比整条船还要大。','行李散向海面。只能带走一条主戒律。','你被浪潮抛上岸。远处，赌城仍然亮着灯。'];
function paintIntro(){
 $('introArtwork').innerHTML=coverSvg(PitchArt.scene(Math.min(introStep,3)));$('introArtwork').className='intro-art scene-'+introStep;
 $('introHeading').textContent=introTitles[introStep]||'';$('introCaption').textContent=introLines[introStep]||'';$('introIndex').textContent='序章 / '+String(Math.min(introStep+1,4)).padStart(2,'0');
 $('introNext').hidden=introStep===2;$('introNext').textContent=introStep===3?'随浪上岸 →':'继续 →';$('introChoices').replaceChildren();$('introChoices').hidden=introStep!==2;
 if(introStep===2)for(const c of rules.filter(c=>c.slot==='core')){const b=document.createElement('button');b.className='intro-card reward-card';b.innerHTML=cardHTML(c);b.setAttribute('aria-label','选择主戒律 '+c.name+'。'+c.text);b.onclick=()=>selectIntroCore(c.id);$('introChoices').appendChild(b);}
 $('introBlackout').hidden=introStep!==4;if(introStep===4)$('introBlackout').focus();
}
function nextIntro(){if(!introRunning||introStep===2)return;if(introStep===4){finishIntro();return}introStep++;paintIntro();}
function skipIntro(){if(!introRunning)return;if(state.rules.some(id=>rules.find(c=>c.id===id)?.slot==='core')){finishIntro();return}introStep=2;paintIntro();}
function selectIntroCore(id){if(!introRunning||introStep!==2)return;const c=rules.find(c=>c.id===id&&c.slot==='core');if(!c)return;state.rules=[id];recordAction('opening_core',{id});soundNote(500,.18);introStep=3;paintIntro();}
const welcome=[
 ['摆渡人','欢迎来到拉斯科尔，幸存者。\n倒也不必露出那副惊讶的表情。\n那头发狂的白鲸掀翻了整条船，而你活了下来。\n每天都有船试图驶入这座赌城。能抵达的人并不多。'],
 ['摆渡人','关于拉斯科尔，人们讲过无数故事。\n其中最出名的，是十二枚黄金骰。\n据说财富女神阿尔卡索恩将王冠化作十二枚黄金骰散落城中。\n贵族、骗子、佣兵和朝圣者为此来到这里。直到今天也是如此。']
];
function finishIntro(){if(!introRunning)return;introRunning=false;$('introBlackout').hidden=true;show('map');tellStories(welcome,()=>{modal('选择构筑方向','主戒律已经绑定。选择你想追求的方向，再挑选第一张规则卡。',Object.entries(CARD_DATABASE.schools).map(([key,name])=>[name,()=>{state.focus=key;offerRules(false,()=>{state.tutorial='map';renderMap();show('map');saveCheckpoint();$('routeProgress').textContent='新手引导 · 点击最下方的战斗节点';})}]))});}
function tellStories(pages,after){storyState={pages,index:0,after};paintStory();}
function paintStory(){const [speaker,text]=storyState.pages[storyState.index];$('storyPortrait').innerHTML=PitchArt.portrait();$('storySpeaker').textContent=speaker;$('storyText').textContent=text;$('storyProgress').textContent=(storyState.index+1)+' / '+storyState.pages.length;$('storyOverlay').hidden=false;$('storyNext').textContent=storyState.index===storyState.pages.length-1?'继续旅程 →':'继续 →';$('storyNext').focus();}
function advanceStory(skip=false){if(!storyState)return;if(!skip&&storyState.index<storyState.pages.length-1){storyState.index++;paintStory();return}const after=storyState.after;storyState=null;$('storyOverlay').hidden=true;after();}
chooseNode=function(key){if(storyState||introRunning)return;if(state.tutorial==='map'&&key==='0-0'){
 tellStories([['摆渡人','怎么？没人告诉过你这里的规则？\n那倒正常。真正了解拉斯科尔的人，很少会向别人分享经验。\n看到那边的海鸥了吗？先拿它练练手吧。']],()=>{state.tutorial='battle';chooseNode80(key);const core=rules.find(c=>state.rules.includes(c.id)&&c.slot==='core');tellStories([
 ['摆渡人','赌局规则很简单。\n投掷三枚骰子。第一、二掷后，你可以点击骰子保留或解除保留。\n总共有三次机会。通常第三掷后点数更高的一方获胜。\n你的主戒律会改变这个规则：'+core.name+'。'],
 ['摆渡人','看到点数与下方的结算预览了吗？\n规则卡提供的优势会影响最终结果，你和对手的差值就是基础伤害。\n有时帮助你，有时帮助你的对手。\n在拉斯科尔，公平并不是理所当然的事。'],
 ['摆渡人','很快你还会接触到另一种东西，人们称它们为「戒律」。\n戒律会与你绑定。\n正常情况下，一个人只能拥有一条主戒律。\n你已经从海中带回了属于自己的那一条。'],
 ['摆渡人','挑战发起时，这场赌博将使用“挑战发起者”的主戒律。\n本次由你主动挑战，因此使用「'+core.name+'」。\n'+core.text+'\n这就是你构筑规则卡的核心。'],
 ['摆渡人','好了。阿尔卡索恩会不会庇护你，我不知道。\n但那只海鸥已经等得有些不耐烦了。\n去赢下你的第一场赌局吧。']
 ],()=>{state.tutorial='done';renderBattle();toast('第一掷：投掷全部骰子。随后点击骰子锁定。');});});return;}chooseNode80(key);};
startBattle=function(id){startBattle80(id);$('enemyPortrait').innerHTML=PitchArt.portrait(id==='E001'?'gull':'enemy');$('battleSet').innerHTML=coverSvg(PitchArt.backdrop());$('playerPortrait').innerHTML=PitchArt.portrait();};
const cardHTML80=cardHTML;
cardHTML=function(c){return '<div class="card-id">'+c.id+'<span>'+(c.slot==='core'?'主戒律':'规则卡')+'</span></div><div class="card-illustration">'+PitchArt.card(c)+'</div><b>'+c.name+'</b><p>'+c.text+'</p><small>'+c.family+' / '+({enabler:'建立机制',converter:'规则转换',reward:'收益强化',safety:'生存容错'})[c.role]+'</small>';};
renderRules=function(){const support=state.rules.filter(id=>rules.find(c=>c.id===id)?.slot==='support'),core=state.rules.find(id=>rules.find(c=>c.id===id)?.slot==='core');$('ruleCount').textContent=support.length+' / 5 规则卡 · '+(core?1:0)+' / 1 主戒律';$('ruleGrid').innerHTML=state.rules.length?state.rules.map(id=>{const c=rules.find(x=>x.id===id);return '<div tabindex="0" role="button" aria-label="查看 '+c.name+'" data-inspect-card="'+id+'" id="card-'+id+'" class="rule-card '+(c.slot==='core'?'core-card ':'')+(state.triggered.includes(id)?'trigger':'')+'">'+cardHTML(c)+'</div>';}).join(''):'<div class="empty-rules">尚未绑定规则卡</div>';};
function inspectCard(id){const c=rules.find(c=>c.id===id);if(!c||busy||storyState||introRunning)return;modal(c.name,cardHTML(c),[['继续赌局',()=>{}]]);}
document.addEventListener('click',e=>{const card=e.target.closest?.('[data-inspect-card]');if(card)inspectCard(card.getAttribute('data-inspect-card'));});
document.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&e.target.getAttribute?.('data-inspect-card')){e.preventDefault();inspectCard(e.target.getAttribute('data-inspect-card'));}});
document.addEventListener('keydown',e=>{if(!storyState||e.key!=='Tab')return;const buttons=[...$('storyOverlay').querySelectorAll('button:not(:disabled)')],first=buttons[0],last=buttons.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}});
// Pointer tilt is visual only. No draws from gameplay RNG, no layout reads outside one card.
document.addEventListener('pointermove',e=>{if(reducedMotion()||e.pointerType==='touch')return;const card=e.target.closest?.('.reward-card,.rule-card');if(!card)return;const rect=card.getBoundingClientRect(),x=(e.clientX-rect.left)/rect.width-.5,y=(e.clientY-rect.top)/rect.height-.5;card.style.setProperty('--rx',(-y*8).toFixed(2)+'deg');card.style.setProperty('--ry',(x*10).toFixed(2)+'deg');});
document.addEventListener('pointerout',e=>{const card=e.target.closest?.('.reward-card,.rule-card');if(card&&!card.contains(e.relatedTarget)){card.style.setProperty('--rx','0deg');card.style.setProperty('--ry','0deg');}});
$('heroLandscape').innerHTML=coverSvg(PitchArt.scene(3));$('mapLandscape').innerHTML=coverSvg(PitchArt.city());$('battleSet').innerHTML=coverSvg(PitchArt.backdrop());
rulebookPages.base+='<h3>主戒律与挑战</h3><p>本章所有战斗由玩家主动发起，使用玩家所选主戒律，双方遵守同一比较方式。原来的核心槽称为主戒律槽，仍限一条；另外五个位置放置自动触发的规则卡。开场可跳过过场，新手对白也可跳过。减弱动态效果设置会关闭晃动、倾斜与触发弹跳。</p>';
