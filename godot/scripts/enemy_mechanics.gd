class_name EnemyMechanics
extends RefCounted

static func intent(s: Dictionary) -> Dictionary:
	var e=s.enemy
	var n=int(s.roundNumber)
	var m=s.enemyMemory
	var tags=e.mechanics
	if e.rank=="boss" and e.has("phases"):tags=e.phases[1 if e.hp<=e.maxHp/2.0 else 0]
	var o={"seal":-1,"attack":0,"guard":0,"suppress":"","field":"","tax":false,"wager":false,"thrift":false,"repeat":false,"parity":false,"straight":false,"mirror":false,"even":false,"scar":false,"lockhunt":false,"mercy":false,"lines":[]}
	for tag in tags:
		match tag:
			"grow":o.attack+=mini(3,n-1)
			"seal":
				if n%2==0:o.seal=(n+int(e.chapter))%3
			"repeat":o.repeat=true
			"charge":
				if n%4==0:o.attack+=4
			"tax":o.tax=true;o.attack+=int(m.get("tax","")=="refuse")
			"inspect":o.suppress=m.get("suppress","")
			"wager":o.wager=n%2==0
			"tide":o.field="low" if n%2==1 else "high"
			"streak":o.attack+=mini(3,m.get("streak",0))
			"mirror":o.mirror=true
			"even":o.even=e.hp<=e.maxHp/2.0
			"scar":o.scar=n>=3
			"parity":o.parity=true
			"straight":o.straight=n%3==0
			"thrift":o.thrift=n%3==0
			"alternating":
				if n%2==1:o.guard+=2
				else:o.attack+=2
			"lockhunt":o.lockhunt=true
			"echo":
				if m.get("triggers",0)>=3:o.guard+=2
			"mercy":o.mercy=true
	if e.chapter==3 and s.get("fateDebt",0)>=2 and n%3==0:o.attack+=1;o.lines.append("命运债务：额外伤害 +1")
	if o.seal>=0:o.lines.append("第 %d 骰本回合不可锁定" % (o.seal+1))
	if o.attack:o.lines.append("敌方胜出伤害 +%d" % o.attack)
	if o.guard:o.lines.append("敌方护盾 %d" % o.guard)
	if o.repeat:o.lines.append("重复牌型：敌方护盾 +2")
	if o.parity:o.lines.append("重复多数奇偶：敌方护盾 +2")
	if o.straight:o.lines.append("本回合顺子：敌方护盾 +3")
	if o.suppress!="":o.lines.append("本回合抑制 %s：每张优势 -1" % o.suppress)
	if o.field!="":o.lines.append("双方每枚 %s 点骰优势 +1" % ("1–2" if o.field=="low" else "5–6"))
	if o.mirror:o.lines.append("结算复制你的最高骰")
	if o.even:o.lines.append("敌方偶数骰优势 +1")
	if o.scar:o.lines.append("全部重掷：敌方护盾 +2")
	if o.lockhunt:o.lines.append("锁满三骰：敌方胜出伤害 +2")
	if o.mercy:o.lines.append("无锁骰：双方伤害 -2")
	if "charge" in tags:o.lines.append("第 %d 回合蓄力爆发" % (int((n-1)/4.0)*4+4))
	return o

static func guard(s: Dictionary) -> int:
	var i=s.enemyIntent;var m=s.enemyMemory;var pattern=RulesEngine.shape(s.pdice)
	var parity=1 if s.pdice.filter(func(v):return int(v)%2==1).size()>=2 else 0
	return i.guard+(2 if i.repeat and m.get("pattern","")==pattern else 0)+(2 if i.parity and m.get("parity",-1)==parity else 0)+(3 if i.straight and pattern=="顺子" else 0)+(2 if i.scar and s.lastRerolled==3 else 0)

static func after(s: Dictionary, r: Dictionary, db: Dictionary) -> Dictionary:
	var m=s.enemyMemory.duplicate(true)
	m.pattern=RulesEngine.shape(s.pdice)
	m.parity=1 if s.pdice.filter(func(v):return int(v)%2==1).size()>=2 else 0
	m.streak=int(m.get("streak",0))+1 if r.win else (0 if r.lost else m.get("streak",0))
	m.triggers=0
	for id in r.triggered:
		var c=db[id]
		if c.slot=="support":
			m.triggers+=1
			if c.get("school","")!="":m.schools[c.school]=int(m.schools.get(c.school,0))+1
	m.suppress=""
	if int(s.roundNumber)%3==0:
		var highest=0
		for school in m.schools:
			if m.schools[school]>highest:highest=m.schools[school];m.suppress=school
	return m
