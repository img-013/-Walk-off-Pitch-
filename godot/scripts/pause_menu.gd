extends CanvasLayer
var mode="menu"
var action=""
var app: Node
func _ready() -> void:
	app=get_parent()
	$Root/Save.pressed.connect(save_game)
	$Root/Settings.pressed.connect(open_settings)
	$Root/Home.pressed.connect(func():request_confirmation("home"))
	$Root/Quit.pressed.connect(func():request_confirmation("quit"))
	$Root/Resume.pressed.connect(func():
		if mode=="settings" and app.current_page!="MainMenu":open_menu()
		else:close())
	$Root/Yes.pressed.connect(confirm)
	$Root/No.pressed.connect(func():
		if app.current_page=="MainMenu":close()
		else:open_menu())
	for key in ["Master","Music","Effects"]:
		get_node("Root/"+key).value_changed.connect(func(value):
			app.get_node("CabaretAudio").set_level(key,value/100.0)
			get_node("Root/"+key+"Label").text={"Master":"主要音量","Music":"音乐音量","Effects":"音效音量"}[key]+"  %d%%"%value)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if $Root.visible:
			if mode=="confirm":open_menu()
			elif mode=="settings" and app.current_page!="MainMenu":open_menu()
			else:close()
		elif app.current_page!="MainMenu":open_menu()
		else:return
		get_viewport().set_input_as_handled()
func display(next_mode: String) -> void:
	mode=next_mode;$Root.show();$Root/Notice.text=""
	for key in ["Save","Settings","Home","Quit"]:get_node("Root/"+key).visible=mode=="menu"
	for key in ["Master","Music","Effects"]:
		get_node("Root/"+key).visible=mode=="settings"
		get_node("Root/"+key+"Label").visible=mode=="settings"
	$Root/Yes.visible=mode=="confirm";$Root/No.visible=mode=="confirm";$Root/Resume.visible=mode!="confirm"
	get_viewport().gui_release_focus()
func open_menu() -> void:
	display("menu");$Root/Title.text="远征菜单";$Root/Resume.text="返回游戏"
	$Root/Save.disabled=app.game.s.is_empty() or app.game.s.get("phase","") in ["defeat","complete"]
func open_settings() -> void:
	display("settings");$Root/Title.text="声音设置";$Root/Resume.text="返回"
	for key in ["Master","Music","Effects"]:
		var value=app.get_node("CabaretAudio").levels[key]*100.0
		get_node("Root/"+key).set_value_no_signal(value)
		get_node("Root/"+key+"Label").text={"Master":"主要音量","Music":"音乐音量","Effects":"音效音量"}[key]+"  %d%%"%value
func close() -> void:$Root.hide()
func save_game() -> void:
	$Root/Notice.text="已保存当前远征。" if app.game.save() else "保存失败，请检查磁盘空间。"
func request_confirmation(kind: String) -> void:
	action=kind;display("confirm");$Root/Title.text="返回主页？" if kind=="home" else "退出游戏？"
	$Root/Notice.text="将保存当前远征后离开。" if not app.game.s.is_empty() else "确认退出游戏。"
func confirm() -> void:
	if not app.game.s.is_empty() and app.game.s.get("phase","") not in ["defeat","complete"]:
		if not app.game.save():$Root/Notice.text="保存失败，已取消离开。";return
	if action=="home":
		# Finish an in-flight visual before changing pages; settlement already committed.
		app.get_node("SettlementPresenter").skip()
		while app.busy:await get_tree().process_frame
		close();app.show_page("MainMenu")
	elif OS.has_feature("web"):
		$Root/Notice.text="远征已保存，请关闭浏览器标签页。";$Root/Yes.hide()
	else:get_tree().quit()
