extends Node
@export_range(-40.0,0.0) var music_volume_db: float = -15.0
@export_range(-40.0,0.0) var effects_volume_db: float = -9.0
var music_enabled: bool = true
var effects_enabled: bool = true
var levels: Dictionary = {"Master":1.0,"Music":1.0,"Effects":1.0}
var last_hover: int = 0
func _ready() -> void:
	var config=ConfigFile.new()
	if config.load("user://presentation.cfg")==OK:
		music_enabled=config.get_value("audio","music",true)
		effects_enabled=config.get_value("audio","effects",true)
	for bus_name in ["Music","Effects"]:
		if AudioServer.get_bus_index(bus_name)<0:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
	for key in levels:levels[key]=clampf(float(config.get_value("audio",key+"Level",1.0)),0.0,1.0)
	$Music.bus="Music"
	for key in ["Hover","Click","Roll","Reveal"]:get_node(key).bus="Effects"
	get_parent().get_node("SettlementPresenter/Impact").bus="Effects"
	apply_levels()
	$Music.stream=$Music.stream.duplicate()
	$Music.stream.loop=true
	$Music.volume_db=-60.0
	if music_enabled:
		$Music.play()
		create_tween().tween_property($Music,"volume_db",music_volume_db,1.8)
	get_tree().node_added.connect(bind_button)
	for button in get_tree().root.find_children("*","BaseButton",true,false):bind_button(button)
func bind_button(node: Node) -> void:
	if not node is BaseButton or node.has_meta("cabaret_audio"):return
	node.set_meta("cabaret_audio",true)
	node.mouse_entered.connect(func():hover(node))
	node.focus_entered.connect(func():hover(node))
	node.pressed.connect(func():
		if node.name=="RollButton":play("Roll")
		elif node.name=="SettleButton":play("Reveal")
		else:play("Click"))
func hover(button: BaseButton) -> void:
	if button.disabled or Time.get_ticks_msec()-last_hover<110:return
	last_hover=Time.get_ticks_msec()
	play("Hover")
func play(kind: String) -> void:
	if not effects_enabled:return
	var player=get_node(kind) as AudioStreamPlayer
	player.volume_db=effects_volume_db+(-7.0 if kind=="Hover" else 0.0)
	player.play()
func toggle_music() -> void:
	music_enabled=not music_enabled
	if music_enabled:$Music.volume_db=music_volume_db;$Music.play()
	else:$Music.stop()
	save_preferences()
func toggle_effects() -> void:
	effects_enabled=not effects_enabled
	save_preferences()
func save_preferences() -> void:
	var config=ConfigFile.new()
	config.load("user://presentation.cfg")
	config.set_value("audio","music",music_enabled)
	config.set_value("audio","effects",effects_enabled)
	for key in levels:config.set_value("audio",key+"Level",levels[key])
	config.save("user://presentation.cfg")

func set_level(key: String, value: float) -> void:
	if not levels.has(key):return
	levels[key]=clampf(value,0.0,1.0)
	if key=="Music" and value>0 and not music_enabled:music_enabled=true;$Music.volume_db=music_volume_db;$Music.play()
	if key=="Effects" and value>0:effects_enabled=true
	apply_levels();save_preferences()
func apply_levels() -> void:
	for key in levels:
		var index=AudioServer.get_bus_index(key)
		AudioServer.set_bus_mute(index,levels[key]<=0.0)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,levels[key])))
