extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	await process_frame
	app.game.persistence_enabled=false;app.game.fresh("",17);app.game.s.current="0-0"
	EventDirector.begin(app.game,"gothic_faceless_dealer");app.event()
	assert(app.ui("EventOptions").get_child_count()==3)
	await create_timer(1.0).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://event-faceless.png")
	assert(EventDirector.choose(app.game,0));var gold=app.game.s.gold
	assert(gold==(30 if app.game.s.activeEvent.roll>=4 else 15))
	assert(not EventDirector.choose(app.game,0));assert(app.game.s.gold==gold)
	app.render_event();assert(app.ui("EventOptions").get_child_count()==1)
	assert(EventDirector.finish(app.game));assert(app.game.s.phase=="map")
	print("FACELESS PASS: layout, cost, recorded roll, payout, duplicate guard, map return")
	app.queue_free();await process_frame;quit()
