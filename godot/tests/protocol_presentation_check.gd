extends SceneTree
var failures=0
var count=0
func _initialize():call_deferred("check")
func expect(ok: bool, label: String):
	count+=1
	if not ok:failures+=1;push_error(label)
func setup(app: Node, rules: Array, p: Array, e: Array, pot: int=0, wager: String="initiative"):
	app.game.persistence_enabled=false;app.game.battle_experiment_enabled=true;app.game.fresh("",111);app.game.s.rules=rules;app.game.start_battle("E001")
	app.game.s.hp=100;app.game.s.maxHp=100;app.game.s.enemy.hp=100;app.game.s.enemy.maxHp=100
	app.game.s.roll=3;app.game.s.pdice=p;app.game.s.edice=e;app.game.s.publicPot=pot;app.game.s.currentWager=wager
	app.show_page("BattleHUD");app.render_battle();app.update_dice({},false)
func check():
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	await process_frame
	var camera=app.get_node("Tavern/Camera3D").transform
	for scenario in [
		["ordinary",[],[3,3,3],[4,4],0,"initiative"],
		["tie1",[],[2,2,2],[3,3],0,"initiative"],
		["tie2",[],[2,2,2],[3,3],2,"initiative"],
		["chain",["R001","R002","R012"],[1,1,3],[2,2],0,"initiative"],
		["wager_success",[],[5,5,5],[2,2],0,"overwhelm"],
		["wager_failure",[],[2,2,3],[3,3],0,"overwhelm"],
		["pot_payout",[],[5,4,3],[3,3],6,"steal"]]:
		setup(app,scenario[1],scenario[2],scenario[3],scenario[4],scenario[5])
		var started=Time.get_ticks_msec()
		await app.settle_round()
		expect(not app.busy and not app.get_node("SettlementPresenter").playing,scenario[0]+" completed")
		expect(Time.get_ticks_msec()-started<3100,scenario[0]+" timing cap")
		print("SCENARIO ",scenario[0]," damage=",app.last_result.diff," climax=",app.last_result.climax_event.active," ms=",Time.get_ticks_msec()-started)
	setup(app,["R001","R002","R012"],[1,1,3],[2,2],4,"narrow")
	var before=app.game.s.duplicate(true)
	var expected=RulesEngine.evaluate(before,app.game.cards)
	get_tree_timer_skip(app)
	await app.settle_round()
	expect(app.game.s.enemy.hp==before.enemy.hp-expected.diff,"skip exact damage")
	var after=JSON.stringify(app.game.s)
	await app.settle_round();expect(JSON.stringify(app.game.s)==after,"repeated settle no mutation")
	expect(app.get_node("Tavern/Camera3D").transform==camera,"camera untouched")
	setup(app,["R001","R002","R012"],[1,1,3],[2,2],4,"narrow")
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://protocol-preview.png")
	app.queue_free();await process_frame
	print("PRESENTATION: ",count," checks, ",failures," failures")
	quit(1 if failures else 0)
func get_tree_timer_skip(app: Node):
	create_timer(.32).timeout.connect(func():app.ui("SkipSettlement").pressed.emit();app.ui("SkipSettlement").pressed.emit())
