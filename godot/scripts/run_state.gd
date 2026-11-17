class_name RunState
extends RefCounted

var cards: Dictionary = {}
var enemies: Dictionary = {}
var map: Array = []
var s: Dictionary = {}
var rng = RandomNumberGenerator.new()
const SAVE_PATH = "user://expedition-godot-v1.json"

func _init() -> void:
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json")).cards:cards[c.id]=c
	enemies=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	map=JSON.parse_string(FileAccess.get_file_as_string("res://data/map.json"))

func has(key: String) -> bool:
	for id in s.rules:
		if cards[id].effect_key==key:return true
	return false

func fresh(core: String = "", seed_value: int = 0) -> void:
	rng.seed=seed_value if seed_value else Time.get_unix_time_from_system()
	s={"version":1,"seed":str(rng.seed),"hp":30,"maxHp":30,"gold":20,"rules":[core] if core!="" else [],"noCore":core=="","done":[],"current":"","next":["0-0"],"phase":"map","enemy":{},"spendBank":0,"spendRemainder":0,"nextBattleDebt":0,"fateDebt":0,"nodeGold":0,"shopPurchases":0,"faces":[[1,2,3,4,5,6],[1,2,3,4,5,6],[1,2,3,4,5,6]],"encounters":{},"reward":[],"eventIndex":-1}
	var previous_branch=""
	for node in map:
		if node.type not in ["fight","elite","boss"]:continue
		var pool=[]
		for id in enemies:
			var e=enemies[id]
			if e.chapter==node.chapter and (e.rank in ["prototype","variant"] if node.type=="fight" else e.rank==node.type):pool.append(id)
		var diverse=pool.filter(func(id):return enemies[id].branch!=previous_branch)
		if not diverse.is_empty():pool=diverse
		var id=pool[rng.randi_range(0,pool.size()-1)]
		if node.l==0:id="E001"
		s.encounters[node.key]=id;previous_branch=enemies[id].branch

func capacity() -> int:
	return 6 if s.noCore else 5

func start_battle(id: String) -> void:
	s.phase="battle";s.enemy=enemies[id].duplicate(true);s.enemy.id=id;s.enemy.maxHp=s.enemy.hp
	s.roundNumber=1;s.battleLosses=0;s.battleCardGold=0;s.battleHealing=0;s.cardGold={};s.cardHealing={};s.used={};s.carryAdv=0;s.carryShield=0;s.openingAdv=s.spendBank;s.spendBank=0;s.openingDebt=s.nextBattleDebt;s.nextBattleDebt=0;s.previousLockSignature=""
	s.enemyMemory={"streak":0,"schools":{},"suppress":""}
	s.pdice=[1,1,1];s.edice=[]
	for i in range(int(s.enemy.dice)):s.edice.append(1)
	if has("entry_gold"):s.gold+=6
	if has("entry_heal") and s.hp>s.maxHp/2.0:s.hp=mini(s.maxHp,s.hp+3)
	new_round()

func new_round() -> void:
	s.roll=0;s.locked=[false,false,false];s.earlyLocked=[false,false,false];s.lastRerollMask=[false,false,false];s.lastRerolled=0;s.rerollsAfterFirst=0;s.faceChanges=0;s.enemyKept=0;s.physical=[0,0,0];s.enemyPhysical=[0,0,0]
	s.enemyIntent=EnemyMechanics.intent(s)

func lock_die(i: int) -> bool:
	if s.phase!="battle" or s.roll==0 or s.roll>=3 or s.enemyIntent.seal==i:return false
	s.locked[i]=not s.locked[i]
	if s.roll==1:s.earlyLocked[i]=s.locked[i]
	elif not s.locked[i]:s.earlyLocked[i]=false
	return true

func roll() -> Dictionary:
	if s.roll>=3 or s.phase!="battle" or (s.enemyIntent.tax and not s.enemyMemory.has("tax")):return {}
	s.roll+=1
	var pm=[];var em=[]
	for i in range(3):pm.append(not s.locked[i] or s.enemyIntent.seal==i)
	for v in s.edice:em.append(s.roll==1 or (v>3 if has("low_wins") else v<4))
	if s.roll==3 and has("break_lock") and true in s.locked:em[s.edice.find(s.edice.max())]=true
	for i in range(3):
		if not pm[i]:continue
		var face=rng.randi_range(0,5)
		s.physical[i]=face
		s.pdice[i]=int(s.faces[i][face])
		var v=s.pdice[i]
		if i==0 and v==6 and has("face_low"):change_value(i,1)
		if i==0 and v==1 and has("face_mid"):change_value(i,3)
		if i==1 and v==2 and has("face_high"):change_value(i,5)
		if i==2 and v==6 and has("face_center"):change_value(i,3)
	for i in range(s.edice.size()):
		if em[i]:s.edice[i]=rng.randi_range(1,6);s.enemyPhysical[i]=s.edice[i]-1
	if s.roll==3:
		if has("invert_core"):
			for i in range(3):
				if pm[i]:change_value(i,7-int(s.pdice[i]))
			for i in range(s.edice.size()):
				if em[i]:s.edice[i]=7-int(s.edice[i]);s.enemyPhysical[i]=s.edice[i]-1
		if has("flip_lock"):
			for i in range(3):
				if s.earlyLocked[i]:change_value(i,7-int(s.pdice[i]))
		if has("repair_one") and 1 in s.pdice:change_value(s.pdice.find(1),2)
		if has("parity_shape") and RulesEngine.facts(s).sameLocks and s.earlyLocked.count(true)>=2:
			var index=s.locked.find(false)
			if index>=0:change_value(index,mini(6,s.pdice[index]+1))
	s.lastRerollMask=pm;s.lastRerolled=pm.count(true);s.enemyKept=em.count(false)
	if s.roll>1:s.rerollsAfterFirst+=s.lastRerolled
	return {"pm":pm,"em":em}

func change_value(i: int, value: int) -> void:
	if s.pdice[i]!=value:s.pdice[i]=value;s.faceChanges+=1

func settle() -> Dictionary:
	if s.phase!="battle" or s.roll!=3:return {}
	var r=RulesEngine.evaluate(s,cards)
	s.hp=maxi(0,s.hp-r.selfCost-(r.diff if r.lost else 0))
	if s.hp>0:s.hp=mini(s.maxHp,s.hp+r.heal)
	s.enemy.hp=maxi(0,s.enemy.hp-(r.diff if r.win else 0))
	s.gold+=r.gold;s.battleLosses+=int(r.lost);s.battleCardGold+=r.generatedGold;s.battleHealing+=r.heal
	for key in ["cardGold","cardHealing","used","enemyMemory"]:s[key]=r[key]
	s.carryAdv=r.nextAdv;s.carryShield=r.nextShield;s.nextBattleDebt=maxi(s.nextBattleDebt,r.nextDebt);s.previousLockSignature=RulesEngine.signature(s)
	s.roundNumber+=1
	if s.hp<=0:s.phase="defeat";clear_save()
	elif s.enemy.hp<=0:
		s.gold+=int(s.enemy.gold)+(8 if has("battle_gold") else 0)+(8 if s.enemyMemory.get("tax","")=="refuse" else 0)
		s.hp=mini(s.maxHp,s.hp+(2 if has("victory_heal") else 0)+(5 if s.enemy.rank=="elite" else 3))
		s.phase="victory"
	elif s.roundNumber>60:s.phase="defeat";clear_save()
	else:new_round()
	return r

func spend(amount: int) -> bool:
	if amount<0 or s.gold<amount:return false
	s.gold-=amount
	if has("spend_bank"):
		var n=s.spendRemainder+amount
		s.spendBank=mini(3,s.spendBank+int(n/10.0));s.spendRemainder=int(n)%10
	return true

func enemy_choice(choice: String) -> bool:
	if s.roll!=0 or s.phase!="battle":return false
	match choice:
		"pay","refuse":
			if not s.enemyIntent.tax or s.enemyMemory.has("tax"):return false
			if choice=="pay" and not spend(6):return false
			s.enemyMemory.tax=choice
		"wager":
			if not s.enemyIntent.wager or s.enemyMemory.get("wagerRound",0)==s.roundNumber:return false
			s.enemyMemory.wagerRound=s.roundNumber
		"thrift":
			if not s.enemyIntent.thrift or s.enemyMemory.get("thriftRound",0)==s.roundNumber or not spend(4):return false
			s.enemyMemory.thriftRound=s.roundNumber
		_:return false
	s.enemyIntent=EnemyMechanics.intent(s)
	return true

func offer() -> Array:
	var pool=cards.values().filter(func(c):return c.slot=="support" and c.status=="implemented" and c.id not in s.rules)
	var picks=[]
	for i in range(mini(3,pool.size())):
		var index=rng.randi_range(0,pool.size()-1);picks.append(pool[index].id);pool.remove_at(index)
	s.reward=picks
	return picks

func finish_node() -> void:
	var node={}
	for n in map:
		if n.key==s.current:node=n;break
	if node.is_empty():return
	if node.key not in s.done:s.done.append(node.key)
	s.next=node.next;s.current="";s.reward=[];s.phase="map"
	if node.type not in ["fight","elite","boss"] and has("node_gold"):
		var grant=mini(2,8-s.nodeGold);s.gold+=grant;s.nodeGold+=grant
	if node.type=="boss":s.hp=s.maxHp
	if s.next.is_empty():s.phase="complete";clear_save()
	else:save()

func save() -> bool:
	if s.is_empty() or s.phase in ["defeat","complete"]:return false
	s.rngState=str(rng.state)
	var file=FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	if not file:return false
	file.store_string(JSON.stringify(s));file.close()
	return DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)==OK

func resume() -> bool:
	var loaded=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not loaded is Dictionary or loaded.get("version",0)!=1 or not loaded.has_all(["rules","faces","next","phase","rngState"]):return false
	for id in loaded.rules:
		if not cards.has(id):return false
	s=loaded;rng.seed=int(s.seed);rng.state=int(s.rngState)
	return true

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):DirAccess.remove_absolute(SAVE_PATH)
