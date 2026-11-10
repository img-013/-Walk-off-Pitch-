// Authored roster, reproducible export. Variants combine mechanics rather than HP-only swaps.
const fs=require('node:fs'),ES=require('../src/enemy-system.js');
const rows=[
 ['E001','普通海鸥',1,'prototype','pressure',['learn'],12,2],
 ['E002','铁骰守卫',1,'prototype','pressure',['grow'],16,3],
 ['E003','失控魔术师',1,'prototype','dice',['seal'],18,3],
 ['N004','倒计时执行者',1,'prototype','tempo',['charge'],20,3],
 ['N005','双倍或归零',1,'prototype','risk',['wager'],18,3],
 ['V001','裂帆守卫',1,'variant','pressure',['grow','mercy'],20,3],
 ['V002','疲惫魔术师',1,'variant','dice',['seal','scar'],19,3],
 ['E004','镜面赌徒',1,'elite','counter',['mirror'],26,3],
 ['L002','钟楼监工',1,'elite','tempo',['charge','alternating'],26,3],
 ['L003','封印卫士',1,'elite','dice',['seal','lockhunt'],24,3],
 ['B001','概率修士',1,'boss','pressure',['even'],36,3,[['even'],['even','charge']]],
 ['N006','重复审判官',2,'prototype','pattern',['repeat'],24,3],
 ['N007','收税官',2,'prototype','resource',['tax'],24,3],
 ['N008','规则监察者',2,'prototype','counter',['inspect'],26,3],
 ['N009','贪婪赌徒',2,'prototype','tempo',['streak'],24,3],
 ['N010','奇偶书记',2,'prototype','pattern',['parity'],25,3],
 ['V003','债务魔术师',2,'variant','resource',['tax','seal'],26,3],
 ['V004','重复执行者',2,'variant','pattern',['repeat','charge'],27,3],
 ['V005','顺序破坏者',2,'variant','pattern',['straight','alternating'],26,3],
 ['L004','规则总督',2,'elite','counter',['inspect','echo'],32,3],
 ['L005','碎骰狱卒',2,'elite','dice',['seal','alternating'],30,3],
 ['L006','赤金赌王',2,'elite','risk',['wager','streak'],32,3],
 ['B002','审判双生',2,'boss','pattern',['repeat'],44,3,[['repeat','parity'],['inspect','straight']]],
 ['N011','逆序裁判',3,'prototype','field',['tide'],30,3],
 ['N012','封骰猎手',3,'prototype','dice',['lockhunt'],30,3],
 ['N013','终局看守',3,'prototype','pressure',['alternating'],32,3],
 ['V006','偏转猎手',3,'variant','dice',['lockhunt','parity'],32,3],
 ['V007','债务仲裁者',3,'variant','resource',['thrift','charge'],32,3],
 ['V008','余响看守',3,'variant','pressure',['alternating','echo'],34,3],
 ['L007','禁锁审判长',3,'elite','dice',['seal','inspect'],38,3],
 ['L008','末日钟匠',3,'elite','tempo',['charge','streak'],40,3],
 ['L009','铁壁庄家',3,'elite','pressure',['grow','repeat'],40,3],
 ['B003','命运庄主',3,'boss','tempo',['charge'],52,3,[['charge','tide'],['seal','inspect','streak']]]
];
const roster={};for(const [id,name,chapter,rank,branch,mechanics,hp,dice,phases] of rows){const e={name,chapter,rank,branch,mechanics,hp,dice,rerolls:2,gold:id==='E001'?18:rank==='boss'?65:rank==='elite'?38:18+chapter*3,desc:[...new Set([...mechanics,...(phases||[]).flat()])].map(t=>ES.descriptions[t]).join('；'),...(phases?{phases}:{})};e.threat=ES.threat(e);roster[id]=e;}
fs.writeFileSync('data/enemies.json',JSON.stringify(roster,null,2)+'\n');
fs.writeFileSync('docs/enemies10.md','# 33种敌人 · v0.10\n\n13原型 + 8机制变体 + 9精英 + 3首领。第一章11、第二章12、第三章10。所有条目已接入遭遇池。威胁值为固定归一化设计估算，不是胜率。\n\n'+Object.entries(roster).map(([id,e])=>`## ${id} ${e.name}\n\n第${e.chapter}章 / ${e.rank} / ${ES.branches[e.branch]} / 生命${e.hp} / 威胁${e.threat.value}\n\n${e.desc}。${e.phases?'半血切换阶段，下一回合生效：'+e.phases.map((p,i)=>`${i+1}阶段 ${p.join(' + ')}`).join(' → '):''}\n`).join('\n'));
console.log('Exported 33 implemented enemies');
