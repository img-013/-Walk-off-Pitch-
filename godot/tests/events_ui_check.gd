extends SceneTree
var failures=[]
func _initialize() -> void:call_deferred("run")
func verify(ok: bool, message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func capture(name: String) -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://"+name+".png")
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.game.persistence_enabled=false
	await capture("event-menu")
	var original=app.game
	for id in EventDirector.catalog:
		app.open_event_debug(id);await process_frame
		verify(app.current_page=="EventScreen","enter "+id)
		verify(app.ui("EventIllustration").texture!=null,"image "+id)
		verify(app.ui("EventOptions").get_child_count()==EventDirector.catalog[id].options.size(),"option count "+id)
		verify(app.ui("EventOptions").get_child(0).get_global_rect().position.x>root.size.x*.5,"right column "+id)
		if id=="gothic_faceless_dealer":await capture("event-faceless")
		if id=="gothic_mirror_wager":await capture("event-mirror")
		# Every event's leave button reaches result, then returns to the original menu.
		var buttons=app.ui("EventOptions");buttons.get_child(buttons.get_child_count()-1).pressed.emit();await process_frame
		verify(app.game.s.activeEvent.stage=="result","result "+id)
		app.ui("EventOptions").get_child(0).pressed.emit();await process_frame
		verify(app.current_page=="MainMenu" and app.game==original,"debug restored "+id)
	app.game.fresh("",44);app.game.s.done=["a"];app.game.s.phase="map";app.render_map();await process_frame
	var state=JSON.stringify(app.game.s);app.open_event_debug("gothic_golden_contract");app.get_node("PauseMenu").request_confirmation("home");app.get_node("PauseMenu").confirm();await process_frame
	# persistence disabled means save cannot proceed, but debug game must already have been restored.
	verify(app.game==original and JSON.stringify(app.game.s)==state,"pause home preserves original run")
	app.get_node("PauseMenu").close()
	app.get_node("CabaretAudio").play_context(2);verify(app.get_node("CabaretAudio").context_track.ends_with("map_chapter2.mp3"),"chapter2 music")
	app.get_node("CabaretAudio").play_context(3);verify(app.get_node("CabaretAudio").context_track.ends_with("map_chapter3.mp3"),"chapter3 music")
	print("EVENT UI: 10 enter/result/exit flows; debug restoration; chapter music. Failures: ",failures.size())
	app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
