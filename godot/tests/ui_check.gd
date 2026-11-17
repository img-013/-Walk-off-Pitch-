extends SceneTree
var backup = ""
var had_save = false
var failures = 0

func _initialize() -> void:
	call_deferred("check")

func expect(value: bool, message: String) -> void:
	if not value:failures+=1;print("FAIL: ",message)

func check() -> void:
	had_save=FileAccess.file_exists(RunState.SAVE_PATH)
	if had_save:backup=FileAccess.get_file_as_string(RunState.SAVE_PATH)
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.start_menu()
	expect(app.ui("ChoiceButtons").get_child_count()==3,"start menu choices")
	app.open_relics();app.cycle_relic(-1)
	expect(app.relics[app.relic_index]=="","no-relic option")
	app.game.fresh("",123)
	app.game.s.rules=["R001","R002","R003","R004","R005","R006"]
	expect(app.game.capacity()==6,"six supports without core")
	app.game.save()
	var resumed=RunState.new()
	expect(resumed.resume() and resumed.s.rules.size()==6,"six-rule save reload")
	app.game.s.rules=[]
	app.enter_node(app.game.map[0])
	expect(app.game.s.phase=="battle","map enters battle")
	await app.roll_dice()
	app.toggle_lock(0)
	var locked=app.game.s.pdice[0]
	await app.roll_dice()
	expect(app.game.s.pdice[0]==locked,"locked die remains fixed")
	await app.roll_dice()
	expect(app.game.s.roll==3,"three rolls")
	await app.settle_round()
	app.game.s.current="1-0";app.game.s.nodeRewarded=false;app.finish_current()
	expect(app.game.s.phase=="reward","fixed growth node offers reward")
	app.finish_reward(false)
	expect(app.game.s.done.has("1-0"),"reward finishes node once")
	app.game.s.current="7-0";app.game.s.phase="shop";app.game.s.shopPurchases=0;app.game.s.gold=100;app.game.s.shopRefreshed=false;app.game.offer();app.shop()
	var id=app.game.s.reward[0]
	app.take_card(id,false,10)
	expect(app.game.s.phase=="shop" and app.game.s.shopPurchases==1 and app.game.s.rules.has(id),"purchase stays in shop")
	app.game.s.phase="rest";app.rest()
	app.game.s.phase="event";app.event()
	app.collection();app.catalog();app.settings()
	if had_save:
		var file=FileAccess.open(RunState.SAVE_PATH,FileAccess.WRITE);file.store_string(backup);file.close()
	else:app.game.clear_save()
	print("UI FLOW: ",failures," failures; menu, relic, six-rule resume, lock/roll/settle, reward, shop, rest, event, collection checked.")
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)
