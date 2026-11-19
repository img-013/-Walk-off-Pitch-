class_name BattleProtocol
extends RefCounted

static var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_experiment.json"))

static func enabled(s: Dictionary) -> bool:
	return s.get("battle_experiment_enabled",config.battle_experiment_enabled)

static func event(kind: String, source: String, resource: String, before: float, delta: float, target: String = "PlayerTotal", label: String = "") -> Dictionary:
	return {"type":kind,"source_rule_id":source,"resource":resource,"before":before,"delta":delta,"after":before+delta,"animate":delta!=0 or kind not in ["RULE_TRIGGER","CORE_RULE_TRIGGER"],"ui_element":target,"sound":("climax" if kind=="CLIMAX_EVENT" else ("chip" if kind.begins_with("PUBLIC_POT") else ("trigger" if kind in ["RULE_TRIGGER","CORE_RULE_TRIGGER"] else "none"))),"label":label}

static func wager(s: Dictionary) -> Dictionary:
	return config.wagers.get(s.get("currentWager",""),{})

static func choose(s: Dictionary) -> String:
	if config.wagers.has(s.get("debugWager","")):return s.debugWager
	var pool=config.enemy_pools.get(s.enemy.id,config.default_pool)
	return pool[(int(s.roundNumber)-1)%pool.size()]

# Called before shields and existing enemy modifiers, never by the presenter.
static func damage(s: Dictionary, r: Dictionary, extra: int) -> int:
	r.baseDamage=r.baseDifference;r.ruleExtraRequested=extra;r.wagerDamage=0;r.potDamage=0;r.potBefore=s.get("publicPot",0);r.potAfter=r.potBefore;r.wagerShield=0;r.tacticalGain=0;r.wagerCompleted=false
	if enabled(s):
		if r.win or r.lost:r.baseDamage=maxi(config.minimum_damage,r.baseDifference)
		else:r.potAfter=mini(config.pot_cap,r.potBefore+config.pot_step)
		var w=wager(s)
		if r.win and not w.is_empty():
			match s.currentWager:
				"overwhelm":
					if r.effectiveDifference>=w.gap:r.wagerDamage=w.damage;r.wagerCompleted=true
				"initiative":
					if s.get("earlyStop",false) and s.roll==w.roll:r.wagerShield=w.shield;r.wagerCompleted=true
				"steal":
					if r.potBefore>=w.pot:r.wagerDamage=w.damage;r.wagerCompleted=true
				"narrow":
					if r.effectiveDifference>=w.min_gap and r.effectiveDifference<=w.max_gap:
						r.tacticalGain=mini(w.tokens,config.tactical_cap-s.get("tacticalTokens",0));r.wagerCompleted=true
		if r.win or r.lost:r.potAfter=0
	var cap=int(config.extra_cap) if enabled(s) else 6
	r.ruleExtra=mini(cap,extra) if r.win else 0
	r.wagerDamage=mini(r.wagerDamage,cap-r.ruleExtra)
	if enabled(s) and (r.win or r.lost):r.potDamage=mini(r.potBefore,maxi(0,cap-r.ruleExtra-r.wagerDamage-r.get("enemyExtra",0)))
	r.diff=r.baseDamage
	return r.ruleExtra+r.wagerDamage+r.potDamage

static func finish(s: Dictionary, r: Dictionary) -> void:
	var events: Array=r.events
	events.append(event("FINAL_SCORE","","score",r.p,0,"PlayerTotal","你的最终得分"))
	events.append(event("FINAL_SCORE","","score",r.e,0,"EnemyTotal","敌方最终得分"))
	events.append(event("COMPARE_RESULT","","gap",0,r.baseDifference,"SettlementText","获胜" if r.win else ("落败" if r.lost else "平局")))
	events.append(event("BASE_DAMAGE","","damage",0,r.baseDamage if r.win or r.lost else 0,"SettlementText","基础伤害"))
	if r.ruleExtra:events.append(event("RULE_DAMAGE","","damage",0,r.ruleExtra,"SettlementText","规则额外伤害（上限后）"))
	if enabled(s):
		if r.wagerCompleted:
			for pair in [["damage",r.wagerDamage],["bank_shield",r.wagerShield],["token",r.tacticalGain]]:
				if pair[1]:events.append(event("WAGER_REWARD",s.currentWager,pair[0],0,pair[1],"WagerLabel",wager(s).name))
		if r.win or r.lost:
			if r.potBefore:events.append(event("PUBLIC_POT_PAYOUT","","damage",0,r.potDamage,"PublicPot","公共赌注兑现（消耗 %d）"%r.potBefore))
		else:events.append(event("PUBLIC_POT_ADD","","pot",r.potBefore,r.potAfter-r.potBefore,"PublicPot","筹码入池"))
	var raw=(r.baseDamage+r.ruleExtra+r.wagerDamage+r.potDamage+r.get("enemyExtra",0)) if r.win or r.lost else 0
	if r.get("enemyExtra",0):events.append(event("ENEMY_DAMAGE","","damage",0,r.enemyExtra,"SettlementText","敌人原有额外伤害"))
	if raw!=r.diff:events.append(event("DAMAGE_MODIFIER","","damage",raw,r.diff-raw,"SettlementText","护盾／旧规则修正"))
	var reasons: Array=[];var unique={}
	for e in events:
		if e.type=="RULE_TRIGGER" and e.delta!=0 and e.get("effective",true):unique[e.source_rule_id]=true
	if enabled(s):
		if r.potDamage>0 and r.potBefore>=config.climax_pot:reasons.append("公共赌注兑现")
		if r.wagerCompleted and s.currentWager=="overwhelm":reasons.append("压倒达成")
		if unique.size()>=config.climax_rules:reasons.append("规则连锁")
		if r.diff>=config.climax_damage:reasons.append("高额伤害")
		if s.get("debugClimax",false):reasons.append("调试强制爆发")
	r.climax_event={"active":not reasons.is_empty(),"reasons":reasons,"debug":s.get("debugClimax",false)}
	if not reasons.is_empty():events.append(event("CLIMAX_EVENT","","climax",0,1,"SettlementText"," · ".join(PackedStringArray(reasons))))
	events.append(event("FINAL_DAMAGE","","damage",0,r.diff,"SettlementText","造成伤害" if r.win else ("受到伤害" if r.lost else "平局无伤")))
	r.settlement_id="%s:%s:%s"%[s.get("seed",""),s.get("current",""),s.roundNumber]
