class_name RulesEngine
extends RefCounted

static func total(a: Array) -> int:
	var n = 0
	for v in a: n += int(v)
	return n

static func shape(a: Array) -> String:
	var unique = {}
	for v in a: unique[int(v)] = true
	if unique.size() == 1 and a.size() == 3: return "三同"
	if unique.size() < a.size(): return "对子"
	if a.size() == 3 and a.max()-a.min() == 2: return "顺子"
	return "散点"

static func signature(s: Dictionary) -> String:
	var parts: PackedStringArray = []
	for i in range(3):
		if s.locked[i]: parts.append("%d:%d" % [i,int(s.pdice[i])%2])
	return "|".join(parts)

static func facts(s: Dictionary) -> Dictionary:
	var a = s.pdice
	var f = {"odd":0,"even":0,"small":0,"high":0,"locks":0,"early":0,"lockedOdd":0,"lockedEven":0,"lockedHigh":0,"rerolledOnes":0,"rerolledLow":0,"singleHigh":false}
	f.pair = shape(a) in ["对子","三同"]
	f.triple = shape(a) == "三同"
	f.straight = shape(a) == "顺子"
	f.unique = not f.pair
	f.lowRisk = s.hp < s.maxHp/2.0
	for i in range(3):
		var v = int(a[i])
		f.odd += int(v%2==1); f.even += int(v%2==0)
		f.small += int(v<=2); f.high += int(v>=5)
		f.locks += int(s.locked[i]); f.early += int(s.earlyLocked[i])
		f.lockedOdd += int(s.locked[i] and v%2==1)
		f.lockedEven += int(s.locked[i] and v%2==0)
		f.lockedHigh += int(s.locked[i] and v>=5)
		f.rerolledOnes += int(s.lastRerollMask[i] and v==1)
		f.rerolledLow += int(s.lastRerollMask[i] and v<=2)
		if s.lastRerolled==1 and s.lastRerollMask[i] and v>=5: f.singleHigh=true
	f.sameLocks = f.locks>=2 and s.get("previousLockSignature","")!="" and signature(s)==s.previousLockSignature
	return f

static func condition(key: String, s: Dictionary, f: Dictionary, r: Dictionary) -> int:
	match key:
		"allEven": return int(f.even==3)
		"twoOdd": return int(f.odd>=2)
		"six": return int(6 in s.pdice)
		"singleHigh": return int(f.singleHigh)
		"twoHigh": return int(f.high>=2)
		"sum15": return int(total(s.pdice)>=15)
		"smallWin": return int(f.small>0 and r.win)
		"sum7": return int(total(s.pdice)<=7)
		"one": return int(1 in s.pdice)
		"allLow": return int(s.pdice.max()<=3)
		"twoLocks": return int(f.locks>=2)
		"twoEarly": return int(f.early>=2)
		"sameLocks": return int(f.sameLocks)
		"fourRerolls": return int(s.rerollsAfterFirst>=4)
		"rerolledOnes": return f.rerolledOnes
		"noReroll": return int(s.lastRerolled==0)
		"twoUnique": return int(s.lastRerolled==2 and f.unique)
		"hp10": return int(s.hp<=10)
		"canPay": return int(s.hp>1)
		"lost": return int(r.lost)
		"firstRound": return int(s.roundNumber==1)
		"bigHit": return int(r.lost and r.diff>=5 and s.hp-r.diff-r.selfCost>0 and not s.used.get("R062",false))
		"lockedOdd": return mini(2,f.lockedOdd)
		"riskRerolls": return s.lastRerolled if f.lowRisk else 0
		"changedPair": return int(s.faceChanges>0 and f.pair)
		"rerolledLow": return mini(2,f.rerolledLow)
		"unhurt": return int(not r.lost or r.diff==0)
		"lowRiskLoss": return int(f.lowRisk and total(s.pdice)<=9 and r.lost and not s.used.get("R028",false))
		"exactKill": return int(r.win and r.diff==s.enemy.hp)
	push_error("Unsupported card condition: "+key)
	return 0

static func base_score(a: Array, key: String) -> int:
	match key:
		"max_only": return a.max()
		"target12": return maxi(0,12-absi(total(a)-12))
		"parity_core": return a.max()+2*a.filter(func(v): return int(v)%2==0).size()
		"combo_core": return {"三同":18,"顺子":15,"对子":12}.get(shape(a),total(a))
	return total(a)

static func grant_gold(c: Dictionary, amount: int, s: Dictionary, r: Dictionary) -> void:
	var n = mini(amount,maxi(0,mini(int(c.params.get("cap",12))-int(r.cardGold.get(c.id,0)),12-int(s.battleCardGold)-int(r.generatedGold))))
	if n>0:
		r.cardGold[c.id]=int(r.cardGold.get(c.id,0))+n; r.generatedGold+=n
		emit(r,c,"金币",n)

static func emit(r: Dictionary, c: Dictionary, label: String, n: int) -> void:
	if not c.is_empty() and c.id not in r.triggered: r.triggered.append(c.id)
	r.lines.append("%s · %s %d" % [c.get("name","赌局"),label,n])

## Pure calculation: input state and physical dice are never modified.
static func evaluate(s: Dictionary, db: Dictionary) -> Dictionary:
	s=s.duplicate(true)
	s.pdice=s.pdice.map(func(v):return int(v))
	s.edice=s.edice.map(func(v):return int(v))
	var cards: Array = []
	var has = {}
	for id in s.rules:
		cards.append(db[id]); has[db[id].effect_key]=db[id]
	var a = s.pdice
	var enemy = s.edice.duplicate()
	var f = facts(s)
	var r = {"p":0,"e":0,"win":false,"lost":false,"tie":false,"diff":0,"selfCost":0,"gold":0,"heal":0,"generatedGold":0,"nextAdv":0,"nextShield":0,"nextDebt":0,"cardGold":s.cardGold.duplicate(),"cardHealing":s.cardHealing.duplicate(),"used":s.used.duplicate(),"lines":[],"triggered":[]}
	var intent = s.enemyIntent
	if intent.mirror: enemy[0]=a.max()
	var core = {}
	for c in cards:
		if c.slot=="core": core=c
	var single = has.has("max_only")
	var reversed = has.has("low_wins")
	r.p=base_score(a,core.get("effect_key","")); r.e=base_score(enemy,core.get("effect_key",""))
	if single and r.p==r.e: r.p=total(a); r.e=total(enemy)
	r.lines.append("基础点数 %d : %d" % [r.p,r.e])
	var bonuses = {}
	for c in cards:
		var n = int(c.params.get("amount",0))
		var b = 0
		match c.effect_key:
			"odd_bonus": b=f.odd*n
			"even_bonus": b=f.even*n
			"pair_bonus": b=n if f.pair else 0
			"unique_bonus": b=n if f.unique else 0
			"low_hp": b=n if f.lowRisk else 0
			"small_bonus": b=f.small*n
			"straight_bonus": b=n if f.straight else 0
			"triple_bonus": b=n if f.triple else 0
			"early_lock": b=f.early*n
			"one_reroll": b=n if s.lastRerolled==1 else 0
			"all_reroll": b=n if s.lastRerolled==3 else 0
			"enemy_even": b=n if s.lastRerolled>0 and s.edice.filter(func(v):return int(v)%2==0).size()>=c.params.count else 0
			"glass_pact": b=n
			"loss_growth": b=mini(c.params.cap,s.battleLosses*n)
			"six_bonus": b=n if 6 in a else 0
		for ef in c.get("effects",[]):
			if ef.op=="adv" and condition(ef.when,s,f,r)>0:
				b+=int(ef.amount)
				if c.effect_key=="blood_edge": r.selfCost=1
		if b: bonuses[c.id]=b
	if has.has("even_amp") and f.even==3 and bonuses.has("R011"): bonuses.R034=bonuses.R011
	if has.has("adjacent_echo"):
		var supports = cards.filter(func(c):return c.slot=="support")
		for i in range(1,supports.size()):
			if supports[i].id!="R027": continue
			var left=supports[i-1]
			if not bonuses.has(left.id): continue
			for c in supports:
				if c.get("school","")!="" and c.school!=left.school and bonuses.has(c.id): bonuses.R027=mini(2,ceili(bonuses[left.id]/2.0))
	var shield=int(s.carryShield)
	var extra=0
	var adv=int(s.carryAdv)
	var even_bonus=int(bonuses.get("R011",0))+int(bonuses.get("R034",0))
	if has.has("risk_cash") and f.lowRisk and adv: extra+=mini(3,adv);adv=0
	if has.has("even_shield"):
		bonuses.erase("R011");bonuses.erase("R034");shield+=mini(4,even_bonus)+mini(2,f.lockedEven)
	if has.has("even_cash") and s.faceChanges>0:
		bonuses.erase("R011");bonuses.erase("R034");grant_gold(has.even_cash,int(even_bonus/2.0),s,r)
	for id in bonuses:
		var c=db[id]
		var b=maxi(0,bonuses[id]-(1 if intent.suppress!="" and c.get("school","")==intent.suppress else 0))
		adv+=b;emit(r,c,"优势",b)
	if has.has("high_lock"):
		var n=mini(2,mini(f.lockedHigh,adv));adv-=n;extra+=n
	if s.roundNumber==1: adv+=s.openingAdv-s.openingDebt
	var single_support=0
	if single:
		single_support=mini(3,int(maxi(0,adv)/2.0))
		if adv<0:r.p=maxi(0,r.p+adv)
	else:r.p=maxi(0,r.p+(-adv if reversed else adv))
	var enemy_adv=0
	if intent.even:
		enemy_adv=enemy.filter(func(v):return int(v)%2==0).size()*int(s.enemy.get("evenBonus",1))
		if not single:r.e=maxi(0,r.e+(-enemy_adv if reversed else enemy_adv))
	if intent.field!="":
		var p=0;var e=0
		for v in a:p+=int(v<=2 if intent.field=="low" else v>=5)
		for v in enemy:e+=int(v<=2 if intent.field=="low" else v>=5)
		if single:single_support=mini(3,single_support+int(p/2.0));enemy_adv+=e
		else:r.p=maxi(0,r.p+(-p if reversed else p));r.e=maxi(0,r.e+(-e if reversed else e))
	r.baseDifference=absi(r.p-r.e)
	r.win=r.p<r.e if reversed else r.p>r.e
	r.tie=r.p==r.e
	if r.tie and has.has("tie_win"):r.win=true;r.baseDifference=int(has.tie_win.params.amount)
	r.lost=not r.win and not r.tie;r.diff=r.baseDifference
	if r.win:
		extra+=single_support
		if has.has("desperate") and s.hp<=has.desperate.params.hp:extra+=int(has.desperate.params.amount)
		if has.has("pair_damage") and f.pair:extra+=int(has.pair_damage.params.amount)
	if r.lost:
		r.diff+=intent.attack+(2 if intent.lockhunt and f.locks==3 else 0)
		shield+=(2 if s.enemyMemory.get("thriftRound",0)==s.roundNumber else 0)+single_support
		if single:r.diff+=mini(3,int(enemy_adv/2.0))
		if has.has("close_guard") and r.baseDifference==has.close_guard.params.threshold:r.diff=0
		if has.has("glass_pact"):r.diff+=int(has.glass_pact.params.penalty)
		if has.has("low_guard") and total(a)<=has.low_guard.params.threshold:shield+=int(has.low_guard.params.amount)
	for c in cards:
		for ef in c.get("effects",[]):
			if ef.op not in ["shield","damage"]:continue
			var v=condition(ef.when,s,f,r)
			if v>0 and (ef.op!="damage" or r.win):
				var n=int(ef.amount)*v
				if ef.op=="shield":shield+=n
				else:extra+=n
				emit(r,c,ef.op,n)
	if has.has("lock_core"):shield+=f.locks
	r.playerShield=shield;r.enemyShield=(s.enemyKept if has.has("lock_core") else 0)+EnemyMechanics.guard(s)
	if r.win:r.diff=maxi(0,r.diff+mini(6,extra)-r.enemyShield)
	elif r.lost:r.diff=maxi(0,r.diff-shield)
	else:r.diff=0
	if intent.mercy and f.locks==0:r.diff=maxi(0,r.diff-2)
	if s.enemyMemory.get("wagerRound",0)==s.roundNumber:
		r.diff*=2
		if r.win:r.gold+=2
	if r.win and has.has("all_odd_gold") and f.odd==3:grant_gold(has.all_odd_gold,mini(has.all_odd_gold.params.amount,maxi(0,9-s.battleCardGold)),s,r)
	for c in cards:
		for ef in c.get("effects",[]):
			if ef.op not in ["gold","heal","bankAdv","bankShield"]:continue
			var v=condition(ef.when,s,f,r)
			if v==0:continue
			var n=int(ef.amount)*v
			match ef.op:
				"gold":grant_gold(c,n,s,r)
				"heal":
					if s.hp-r.selfCost-(r.diff if r.lost else 0)>0:
						n=mini(n,mini(maxi(0,6-s.battleHealing-r.heal),maxi(0,int(c.params.get("cap",6))-int(r.cardHealing.get(c.id,0)))))
						if n>0:
							r.heal+=n;r.cardHealing[c.id]=int(r.cardHealing.get(c.id,0))+n;emit(r,c,"恢复",n)
							if c.id=="R062":r.used.R062=true
				"bankAdv":
					r.nextAdv+=n;emit(r,c,"储存优势",n)
					if c.id=="R028":r.used.R028=true;r.nextDebt=2
				"bankShield":r.nextShield+=n;emit(r,c,"储存护盾",n)
	if has.has("gold_core"):r.nextAdv+=int(r.generatedGold/2.0)
	else:r.gold+=r.generatedGold
	r.nextAdv=clampi(r.nextAdv,0,3);r.nextShield=clampi(r.nextShield,0,3)
	r.enemyMemory=EnemyMechanics.after(s,r,db)
	return r
