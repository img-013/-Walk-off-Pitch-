extends SceneTree
var failures=0
var count=0
func _initialize():call_deferred("check")
func expect(ok: bool, name: String):
	count+=1
	if not ok:failures+=1;push_error(name)
func game(exp: bool=true, rules: Array=[]) -> RunState:
	var g=RunState.new();g.persistence_enabled=false;g.battle_experiment_enabled=exp;g.fresh("",123);g.s.rules=rules;g.start_battle("E001");g.s.roll=3;g.s.enemy.hp=100;g.s.enemy.maxHp=100;g.s.currentWager="initiative"
	return g
func score(g: RunState, p: Array, e: Array) -> Dictionary:
	g.s.pdice=p;g.s.edice=e
	return RulesEngine.evaluate(g.s,g.cards)
func check():
	var g=game(false)
	expect(score(g,[3,3,3],[4,4]).diff==1,"legacy gap 1")
	g.s.battle_experiment_enabled=true
	expect(score(g,[3,3,3],[4,4]).diff==3,"experimental minimum")
	g.s.publicPot=0
	expect(score(g,[2,2,2],[3,3]).potAfter==2,"tie deposits 2")
	g.s.publicPot=6
	expect(score(g,[2,2,2],[3,3]).potAfter==6,"pot cap")
	var r=score(g,[3,3,3],[4,4])
	expect(r.potDamage==6 and r.diff==9 and r.potAfter==0,"player payout")
	r=score(g,[2,2,2],[4,4]);expect(r.potDamage==6 and r.diff==9,"enemy payout")
	g=game(true,["R007"]);g.s.publicPot=4
	r=score(g,[1,1,1],[4,4]);expect(r.win and r.diff==9,"reverse comparison")
	g=game(true,["R006"]);g.s.publicPot=4
	r=score(g,[2,2,2],[3,3]);expect(r.win and r.potAfter==0 and r.diff==7,"tie win priority")
	g=game(true,["R016","R017","R049","R069","R076"]);g.s.roll=2;g.s.lastRerolled=1;g.s.lastRerollMask=[true,false,false];g.s.locked=[true,true,true]
	expect(g.stop_early(),"early stop accepted")
	r=score(g,[3,3,3],[4,4]);expect(r.p==9 and r.playerShield==0,"third-roll effects excluded")
	expect(g.roll().is_empty() and not g.stop_early(),"stopped phase immutable")
	g=game(true,["R001","R002","R012"])
	r=score(g,[1,1,3],[2,2]);var ids=[]
	for e in r.events:
		if e.type=="RULE_TRIGGER" and e.resource=="score":ids.append(e.source_rule_id)
	expect(ids==["R001","R002","R012"],"support contribution order")
	expect(r.climax_event.active,"three-rule climax")
	g=game();g.s.currentWager="overwhelm";r=score(g,[5,5,5],[3,3]);expect(r.wagerDamage==3 and r.wagerCompleted,"overwhelm success")
	r=score(g,[3,3,3],[4,4]);expect(not r.wagerCompleted,"overwhelm failure")
	g.s.currentWager="steal";g.s.publicPot=4;r=score(g,[3,3,3],[4,4]);expect(r.wagerDamage==2 and r.potDamage==4,"steal shared cap")
	g.s.currentWager="narrow";r=score(g,[3,3,3],[4,4]);expect(r.tacticalGain==1,"narrow token")
	g.s.tacticalTokens=2;r=score(g,[3,3,3],[4,4]);expect(r.tacticalGain==0,"token cap")
	g.s.roll=2;g.s.pdice=[5,6,1];expect(g.use_tactical(0) and g.s.pdice[0]==6 and g.s.tacticalTokens==1,"tactical increment")
	expect(not g.use_tactical(1) and g.s.tacticalTokens==1,"max face no consumption")
	g.s.currentWager="initiative";g.stop_early();g.s.edice=[2,2];r=g.settle();expect(r.wagerShield==2 and g.s.carryShield>=2,"initiative bank shield")
	var state=JSON.stringify(g.s);expect(g.settle().is_empty() and JSON.stringify(g.s)==state,"duplicate settlement rejected")
	g=game();g.s.pdice=[2,2,2];g.s.edice=[3,3];g.settle();g.s.roll=3;g.settle();expect(g.s.publicPot==4,"two ties accumulate")
	g.s.roll=3;g.s.pdice=[3,3,3];r=g.settle();expect(r.potBefore==4 and r.potAfter==0 and r.climax_event.active,"two ties then win")
	# Presentation consumes a detached immutable event snapshot.
	var snapshot=JSON.stringify(g.s);var events=r.events.duplicate(true);events.clear();expect(JSON.stringify(g.s)==snapshot,"skipping event consumption never mutates state")
	g=game(true,["R006"]);g.s.currentWager="narrow";r=score(g,[2,2,2],[3,3]);expect(r.tacticalGain==0,"synthetic tie-win gap is not narrow win")
	g=game();g.s.enemyIntent.attack=4;g.s.publicPot=6;r=score(g,[1,1,1],[6,6]);expect(r.potDamage==2,"enemy legacy extras reserve shared cap")
	g=game(true,["R009","R024","R035","R036"]);g.s.hp=9;g.s.publicPot=6;g.s.currentWager="overwhelm";r=score(g,[6,6,5],[1,1])
	var damage_sum=0
	for e in r.events:
		if e.type=="RULE_TRIGGER" and e.resource=="damage":damage_sum+=e.delta
	expect(damage_sum==r.ruleExtra and damage_sum<=6 and r.potDamage==0,"damage attribution after cap")
	g=game(true,["R011","R034","R067"]);g.s.locked=[true,true,false];r=score(g,[2,2,2],[5,5]);expect(r.p==6 and r.playerShield==6,"even conversion provides shield not score")
	for e in r.events:
		if e.source_rule_id=="R067":expect(e.resource=="shield","shield event type")
	g=game(true,["R040"]);g.s.hp=g.s.maxHp;r=score(g,[2,6,6],[1,1])
	for e in r.events:
		if e.resource=="heal":expect(e.delta==0 and not e.animate,"no fake overheal")
	var cases=JSON.parse_string(FileAccess.get_file_as_string("res://tests/parity.json"))
	var differences=0
	for test in cases:
		var actual=RulesEngine.evaluate(test.state,g.cards)
		for key in test.expected:
			if actual[key]!=test.expected[key]:differences+=1;if differences<5:print("PARITY DIFFERENCE ",test.name," ",key)
	expect(differences==0,"legacy parity")
	print("PROTOCOL: ",count," checks, ",failures," failures; legacy ",cases.size()," cases, ",differences," differences")
	quit(1 if failures else 0)
