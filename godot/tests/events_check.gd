extends SceneTree
var failures: Array=[]
var checks=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func fresh(seed_value: int=8) -> RunState:
	var g=RunState.new();g.persistence_enabled=false;g.battle_experiment_enabled=true;g.fresh("R007",seed_value)
	g.s.hp=20;g.s.gold=100;g.s.rules.append_array(["R001","R002","R003"])
	for n in g.map:
		if n.type=="event":g.s.current=n.key;g.s.next=[n.key];break
	return g
func complete(g: RunState) -> void:
	var guard=0
	while g.s.activeEvent.stage!="result" and guard<6:
		guard+=1
		var e=g.s.activeEvent
		match e.stage:
			"target":
				for old in EventDirector.supports(g):
					if EventDirector.select_target(g,old):break
			"card":check(EventDirector.accept_card(g,e.candidates[0]),"accept candidate")
			"replace":check(EventDirector.accept_card(g,e.reward,EventDirector.replacement_targets(g,e.reward)[0]),"replacement")
	check(g.s.activeEvent.stage=="result","transaction reaches result")
func run() -> void:
	# Every option, multiple deterministic seeds; all random branches receive coverage.
	for id in EventDirector.catalog:
		var data=EventDirector.catalog[id]
		check(ResourceLoader.exists("res://art/events/"+data.image),"image exists "+id)
		for i in range(data.options.size()):
			for seed_value in range(1,25):
				var g=fresh(seed_value);var node=g.s.current;var before_done=g.s.done.duplicate()
				EventDirector.begin(g,id)
				check(EventDirector.choose(g,i),"choose %s/%d"%[id,i])
				var snapshot=JSON.stringify(g.s)
				check(not EventDirector.choose(g,i) and JSON.stringify(g.s)==snapshot,"duplicate option blocked")
				if g.s.activeEvent.stage=="card":
					var restored=JSON.parse_string(JSON.stringify(g.s));check(restored.activeEvent.candidates==g.s.activeEvent.candidates,"persist candidates")
				complete(g)
				check(g.s.hp>=0 and g.s.gold>=0,"nonnegative resources")
				check(EventDirector.supports(g).size()<=g.capacity(),"card limit")
				var result=g.s.activeEvent.result
				if g.s.activeEvent.roll>0:check(not result.is_empty(),"recorded random outcome")
				check(EventDirector.finish(g),"finish "+id)
				check(not EventDirector.finish(g),"duplicate finish blocked")
				check(node in g.s.done and g.s.done.size()==before_done.size()+1 and g.s.phase=="map","map preserved")
	# No money / voluntary lethal costs are unavailable.
	var g=fresh();g.s.gold=0;g.s.hp=3;EventDirector.begin(g,"gothic_faceless_dealer")
	check(not EventDirector.choose(g,0) and not EventDirector.choose(g,1),"insufficient resources disabled")
	check(EventDirector.choose(g,2),"leave remains usable")
	# Full slots and exclusive groups use a forced, legal replacement.
	g=fresh();g.s.rules.append_array(["R004","R005"]);EventDirector.begin(g,"gothic_broken_marionette")
	check(EventDirector.choose(g,0) and g.s.activeEvent.stage=="replace","full slots replacement screen")
	complete(g);check(EventDirector.supports(g).size()==5,"full-slot size unchanged")
	g=fresh();g.s.rules=["R066"];EventDirector.begin(g,"gothic_broken_marionette");g.s.activeEvent.stage="card";g.s.activeEvent.candidates=["R067"]
	check(EventDirector.accept_card(g,"R067") and g.s.activeEvent.stage=="replace","exclusive pair prompts replacement")
	complete(g);check("R066" not in g.s.rules and "R067" in g.s.rules,"exclusive replacement committed")
	# No reforge loss before commit, resume keeps exact offer.
	g=fresh();EventDirector.begin(g,"gothic_gilded_crucible");EventDirector.choose(g,0)
	var old=g.s.rules.duplicate();EventDirector.select_target(g,"R001")
	check(g.s.rules==old and not EventDirector.finish(g),"uncommitted reforge cannot exit or lose card")
	var copy=JSON.parse_string(JSON.stringify(g.s));check(copy.activeEvent.candidates==g.s.activeEvent.candidates,"reforge persists exact offers")
	complete(g)
	# Synergy candidates use actual metadata.
	g=fresh();EventDirector.begin(g,"gothic_mirror_wager");EventDirector.choose(g,1)
	for id in g.s.activeEvent.candidates:check(id in EventDirector.pool(g,"",true),"real synergy "+id)
	# Apply next battle once, use existing caps and expire next battle.
	g=fresh();g.s.pendingEventEffects={"hp_loss":4,"shield":7,"pot":10,"tokens":5,"free_increment":1};g.s.eventCarriedTokens=1
	g.start_battle("E001")
	check(g.s.hp==16 and g.s.carryShield==7 and g.s.publicPot==6 and g.s.tacticalTokens==2,"pending effects and caps")
	check(not g.s.has("pendingEventEffects"),"pending consumed")
	g.s.roll=1;g.s.pdice=[3,4,6]
	check(g.use_tactical(0) and g.s.pdice[0]==4 and g.s.tacticalTokens==2 and g.s.eventFreeIncrements==0,"free increment consumes only free credit")
	g.s.pendingEventEffects={"shield":4};g.start_battle("E001");check(g.s.carryShield==4,"new shield independent")
	g.s.roll=3;g.s.pdice=[6,6,6];g.s.edice=[1,1];g.settle();check(g.s.carryShield==0,"initial shield expires after first round")
	var hp_before=int(g.s.hp);g.start_battle("E001");check(g.s.hp==hp_before and g.s.carryShield==0 and g.s.publicPot==0 and g.s.eventFreeIncrements==0 and g.s.tacticalTokens==0,"no permanent event buffs")
	g=fresh();g.s.battle_experiment_enabled=false;EventDirector.begin(g,"gothic_loom_fate");check(not EventDirector.choose(g,0) and not EventDirector.choose(g,1),"protocol dependency disabled")
	g=fresh();g.s.hp=3;g.s.pendingEventEffects={"hp_loss":4};g.start_battle("E001");check(g.s.hp==0 and g.s.phase=="defeat","contract lethal debt handled")
	print("EVENT CHECKS: ",checks," / failures: ",failures.size())
	quit(0 if failures.is_empty() else 1)

