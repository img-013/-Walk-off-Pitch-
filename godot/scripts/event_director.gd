class_name EventDirector
extends RefCounted
# All random draws and rewards commit here, never in a UI callback/tween.
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/events.json"))

static func begin(g: RunState, id: String) -> void:
	if not g.s.get("activeEvent",{}).is_empty():return
	g.s.phase="event"
	g.s.activeEvent={"id":id,"stage":"choice","result":"","roll":0,"candidates":[],"target":"","reward":""}
	g.save()

static func supports(g: RunState) -> Array:
	return g.s.rules.filter(func(id):return g.cards[id].slot=="support")

static func pool(g: RunState, rarity: String="", related: bool=false, target: String="") -> Array:
	var result=[]
	for c in g.cards.values():
		if c.slot!="support" or c.status!="implemented" or c.id in g.s.rules:continue
		if rarity!="" and c.rarity!=rarity:continue
		if target!="" and not legal_replacement(g,c.id,target):continue
		if related:
			var matches=false
			for owned in g.s.rules:
				var old=g.cards[owned]
				if c.school==old.school or owned in c.get("synergies",[]) or c.id in old.get("synergies",[]):matches=true
			if not matches:continue
		result.append(c.id)
	return result

static func legal_replacement(g: RunState, id: String, target: String) -> bool:
	var group=g.cards[id].get("exclusive_group","")
	for old in g.s.rules:
		if old==target:continue
		if old==id:return false
		if group!=null and group!="" and group==g.cards[old].get("exclusive_group",""):return false
	return true

static func replacement_targets(g: RunState, id: String) -> Array:
	var support=supports(g)
	var conflicts=support.filter(func(k):return not legal_replacement(g,id,"") and g.cards[id].get("exclusive_group","")==g.cards[k].get("exclusive_group",null))
	return conflicts if not conflicts.is_empty() else (support if support.size()>=g.capacity() else [])

static func reason(g: RunState, option: Dictionary) -> String:
	if g.s.gold<option.get("gold_cost",0):return "金币不足"
	# Voluntary blood prices cannot kill the player. Random judgement may.
	if g.s.hp<=option.get("hp_cost",0):return "生命不足（须保留至少 1 点）"
	if option.get("protocol",false) and not BattleProtocol.enabled(g.s):return "需要开启赌桌协议"
	var action=option.get("action","")
	if action in ["exchange","reforge","sell"] and supports(g).is_empty():return "没有可用的辅助规则"
	if action in ["card","choose","gamble_card"] and pool(g,option.get("rarity",""),option.get("related",false)).is_empty():return "没有符合条件的未持有规则"
	if action in ["exchange","reforge"]:
		var valid=false
		for old in supports(g):
			if not pool(g,g.cards[old].rarity if action=="exchange" else "",false,old).is_empty():valid=true
		if not valid:return "没有可替换规则"
	return ""

static func draw(g: RunState, source: Array, count: int) -> Array:
	var available=source.duplicate();var result=[]
	while not available.is_empty() and result.size()<count:
		var i=g.rng.randi_range(0,available.size()-1);result.append(available.pop_at(i))
	return result

static func pending(g: RunState, key: String, amount: int) -> void:
	if not g.s.has("pendingEventEffects"):g.s.pendingEventEffects={}
	g.s.pendingEventEffects[key]=g.s.pendingEventEffects.get(key,0)+amount

static func choose(g: RunState, index: int) -> bool:
	var e=g.s.get("activeEvent",{})
	if e.get("stage","")!="choice":return false
	var options=catalog[e.id].options
	if index<0 or index>=options.size():return false
	var o=options[index]
	if reason(g,o)!="":return false
	e.stage="result";e.option=index;e.result=o.get("outcome","你离开了赌桌。")
	var cost=int(o.get("gold_cost",0))
	if cost>0:g.spend(cost)
	g.s.hp-=int(o.get("hp_cost",0))
	var before_hp=int(g.s.hp)
	g.s.hp=mini(g.s.maxHp,g.s.hp+int(o.get("heal",0)))
	g.s.gold+=int(o.get("gold",0))
	if cost>0:e.result+="\n支付 %d 金币。"%cost
	if o.get("hp_cost",0)>0:e.result+="\n失去 %d 生命。"%o.hp_cost
	if o.get("heal",0)>0:e.result+="\n实际恢复 %d 生命。"%(g.s.hp-before_hp)
	if o.get("gold",0)>0:e.result+="\n获得 %d 金币。"%o.gold
	for key in o.get("pending",{}):pending(g,key,int(o.pending[key]))
	match o.get("action",""):
		"gamble_gold","gamble_card","judgement":
			e.roll=g.rng.randi_range(1,6);e.result+="\n骰子落定：%d。"%e.roll
			if o.action=="gamble_gold":
				if e.roll>=4:g.s.gold+=15;e.result+="\n赢得 15 金币。"
				else:e.result+="\n庄家收走了赌注，没有奖励。"
			elif o.action=="gamble_card":
				if e.roll>=5:offer(g,o,1)
				else:e.result+="\n鲜血被收下，没有奖励。"
			else:
				if e.roll<=2:g.s.hp=maxi(0,g.s.hp-5);e.result+="\n失去 5 生命。"
				else:
					var gold=10 if e.roll<=4 else 25;g.s.gold+=gold;e.result+="\n获得 %d 金币。"%gold
		"card":offer(g,o,1)
		"choose":offer(g,o,3)
		"exchange","reforge","sell":e.stage="target";e.action=o.action
		"mystery":
			e.roll=g.rng.randi_range(1,3)
			match int(e.roll):
				1:g.s.gold+=8;e.result+="\n货物中藏着 8 金币。"
				2:
					var heal=mini(6,g.s.maxHp-g.s.hp);g.s.hp+=heal;e.result+="\n实际恢复 %d 生命。"%heal
				3:
					var before=int(g.s.get("eventCarriedTokens",0));g.s.eventCarriedTokens=mini(BattleProtocol.config.tactical_cap,before+1)
					e.result+="\n获得 %d 战术筹码（携带至下一场战斗）。"%(g.s.eventCarriedTokens-before)
	g.save();return true

static func offer(g: RunState, o: Dictionary, count: int) -> void:
	var e=g.s.activeEvent
	e.candidates=draw(g,pool(g,o.get("rarity",""),o.get("related",false)),count)
	if e.candidates.is_empty():e.result+="\n无符合条件的新规则。";return
	e.stage="card"
	if count==1:accept_card(g,e.candidates[0])

static func select_target(g: RunState, old: String) -> bool:
	var e=g.s.activeEvent
	if e.stage!="target" or old not in supports(g):return false
	if e.action=="sell":
		g.s.rules.erase(old);g.s.gold+=12;e.result+="\n售出「%s」，获得 12 金币。"%g.cards[old].name;e.stage="result"
	else:
		var candidates=pool(g,g.cards[old].rarity if e.action=="exchange" else "",false,old)
		if candidates.is_empty():return false
		e.target=old;e.candidates=draw(g,candidates,1 if e.action=="exchange" else 3);e.stage="card"
		if e.action=="exchange":accept_card(g,e.candidates[0])
	g.save();return true

static func accept_card(g: RunState, id: String, old: String="") -> bool:
	var e=g.s.activeEvent
	if e.stage not in ["card","replace"] or id not in e.candidates or id in g.s.rules:return false
	if e.stage=="replace" and e.reward!=id:return false
	var target=String(e.target) if e.target!="" else old
	var targets=replacement_targets(g,id)
	if target=="" and not targets.is_empty():e.stage="replace";e.reward=id;g.save();return true
	if target!="" and (target not in supports(g) or (e.target=="" and target not in targets)):return false
	if not legal_replacement(g,id,target):return false
	if target=="" and supports(g).size()>=g.capacity():return false
	if target!="":g.s.rules.erase(target)
	g.s.rules.append(id);e.stage="result";e.result+="\n获得「%s」。"%g.cards[id].name
	if target!="":e.result+="\n替换「%s」。"%g.cards[target].name
	g.save();return true

static func finish(g: RunState) -> bool:
	if g.s.get("activeEvent",{}).get("stage","")!="result":return false
	g.s.erase("activeEvent")
	if g.s.hp<=0:g.s.phase="defeat";g.clear_save()
	else:g.finish_node()
	return true

static func consume_pending(g: RunState) -> void:
	var p: Dictionary=g.s.get("pendingEventEffects",{}).duplicate()
	g.s.erase("pendingEventEffects") # consume before applying, including expired protocol benefits
	g.s.hp=maxi(0,g.s.hp-int(p.get("hp_loss",0)))
	g.s.carryShield+=int(p.get("shield",0))
	g.s.eventFreeIncrements=int(p.get("free_increment",0)) if BattleProtocol.enabled(g.s) else 0
	if BattleProtocol.enabled(g.s):
		g.s.publicPot=mini(int(BattleProtocol.config.pot_cap),int(p.get("pot",0)))
		g.s.tacticalTokens=mini(int(BattleProtocol.config.tactical_cap),int(g.s.get("tacticalTokens",0))+int(p.get("tokens",0)))
	if g.s.hp<=0:g.s.phase="defeat";g.clear_save()
