extends SceneTree
func _initialize():call_deferred("check")
func check():
	var prefs_path="user://presentation.cfg"
	var existed=FileAccess.file_exists(prefs_path)
	var backup=FileAccess.get_file_as_bytes(prefs_path) if existed else PackedByteArray()
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	app.game.persistence_enabled=false;app.game.battle_experiment_enabled=true;app.game.fresh("",432);app.game.start_battle("E001")
	app.game.s.enemy.hp=100;app.game.s.enemy.maxHp=100;app.game.s.roll=3;app.game.s.pdice=[5,5,5];app.game.s.edice=[2,2]
	app.show_page("BattleHUD");app.render_battle();app.update_dice({},false)
	app.get_node("SettlementPresenter").speed=2
	await app.settle_round()
	assert(app.ui("PlayerTotal").text.contains(str(app.last_result.p)))
	assert(app.ui("EnemyTotal").text.contains(str(app.last_result.e)))
	assert(app.ui("SettlementText").text=="")
	var menu=app.get_node("PauseMenu")
	var key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;menu._input(key)
	assert(menu.get_node("Root").visible)
	menu.open_settings()
	var audio=app.get_node("CabaretAudio")
	audio.set_level("Master",.6);audio.set_level("Music",.3);audio.set_level("Effects",0)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")))
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),.6))
	var cfg=ConfigFile.new();cfg.load(prefs_path);assert(is_equal_approx(cfg.get_value("audio","MusicLevel"),.3))
	menu.request_confirmation("home");assert(app.current_page=="BattleHUD" and menu.mode=="confirm")
	menu.get_node("Root/No").pressed.emit();assert(app.current_page=="BattleHUD")
	menu.request_confirmation("quit");assert(menu.mode=="confirm")
	menu.close()
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://local-menu-battle.png")
	menu.open_settings();await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://local-menu-settings.png")
	if existed:
		var f=FileAccess.open(prefs_path,FileAccess.WRITE);f.store_buffer(backup);f.close()
	else:DirAccess.remove_absolute(prefs_path)
	print("LOCAL UI PASS: persistent scores, Esc menu, confirmation cancellation, 3 volume buses and saved preferences")
	app.queue_free();await process_frame;quit()
