extends Node3D

@export var battle_experiment_enabled: bool = BattleProtocol.config.battle_experiment_enabled
@export var animation_speed: float = 1.0
var game = RunState.new()
var busy = false
var relics: Array = []
var relic_index = 0
var current_page = "MainMenu"
var log_lines: PackedStringArray = []
var last_result: Dictionary = {}
var portrait_regions: Dictionary = {}
const NAMES = {"fight":"战斗","elite":"精英","boss":"首领","event":"事件","rest":"酒馆","shop":"商店","altar":"祭坛"}

func ui(node_name: String) -> Node:
	return $Pages/UI.find_child(node_name, true, false)

func _ready() -> void:
	get_viewport().physics_object_picking=true
	game.battle_experiment_enabled=battle_experiment_enabled
	ui("ProtocolButton").pressed.connect(protocol_debug)
	ui("SpeedButton").pressed.connect(cycle_settlement_speed)
	ui("SkipSettlement").pressed.connect(func():$SettlementPresenter.skip())
	ui("EarlyStop").pressed.connect(func():
		if not busy and game.stop_early():update_dice({},false);settle_round())
	ui("TacticalButton").pressed.connect(tactical_menu)
	portrait_regions=JSON.parse_string(FileAccess.get_file_as_string("res://data/portraits.json"))
	for c in game.cards.values():
		if c.slot=="core":relics.append(c.id)
	relics.append("")
	ui("StartButton").pressed.connect(start_menu)
	ui("RulesButton").pressed.connect(rulebook)
	ui("SettingsButton").pressed.connect(settings)
	ui("RelicPrev").pressed.connect(func():cycle_relic(-1))
	ui("RelicNext").pressed.connect(func():cycle_relic(1))
	ui("RelicBack").pressed.connect(func():show_page("MainMenu"))
	ui("RelicConfirm").pressed.connect(begin_run)
	ui("MapCollection").pressed.connect(collection)
	ui("MapSave").pressed.connect(save_home)
	ui("BattleMenu").pressed.connect(save_home)
	ui("RollButton").pressed.connect(roll_dice)
	ui("SettleButton").pressed.connect(settle_round)
	ui("EnemyDetails").pressed.connect(enemy_details)
	ui("DiceDetails").pressed.connect(collection)
	for i in range(3):
		$Tavern/PlayerDice.get_child(i).get_node("ClickArea").input_event.connect(func(_camera,event,_position,_normal,_shape):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and current_page=="BattleHUD" and not ui("ChoiceDialog").visible:toggle_lock(i))
	for i in range(6):
		ui("RuleSlots").get_child(i).pressed.connect(func():show_rule_slot(i))
	for n in game.map:
		ui("Node_"+n.key.replace("-","_")).pressed.connect(func():enter_node(n))
	show_page("MainMenu")
	if "--smoke" in OS.get_cmdline_user_args():
		game.fresh("",12345);game.s.current="0-0";game.start_battle("E001");show_page("BattleHUD");render_battle();update_dice({},false)
	if "--relic-preview" in OS.get_cmdline_user_args():open_relics()
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://godot-preview.png")
		print("PREVIEW: ",ProjectSettings.globalize_path("user://godot-preview.png"))
		get_tree().quit()

func show_page(name: String) -> void:
	current_page=name
	for child in $Pages/UI.get_children():child.visible=child.name==name
	$Tavern/PlayerDice.visible=name=="BattleHUD"
	$Tavern/EnemyDice.visible=name=="BattleHUD"
	ui("ChoiceDialog").hide()

func clear_children(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()

func modal(title: String, text: String, options: Array) -> void:
	ui("DialogPortrait").hide()
	ui("ChoiceTitle").text=title;ui("ChoiceText").text=text;clear_children(ui("ChoiceButtons"))
	for option in options:
		var b=preload("res://scenes/ui/ChoiceButton.tscn").instantiate();b.text=option[0]
		b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		if option.size()>2:b.disabled=option[2]
		var action: Callable=option[1]
		b.pressed.connect(func():ui("ChoiceDialog").hide();action.call())
		ui("ChoiceButtons").add_child(b)
	ui("ChoiceDialog").show()
	get_viewport().gui_release_focus()

func close_dialog() -> void:
	ui("ChoiceDialog").hide()

func start_menu() -> void:
	modal("远征", "继续上次的旅程，或重新选择命运。",[["开始新游戏",confirm_new],["继续远征",resume_run,not FileAccess.file_exists(RunState.SAVE_PATH)],["返回首页",close_dialog]])

func confirm_new() -> void:
	if FileAccess.file_exists(RunState.SAVE_PATH):
		modal("开始新的远征？","确认戒律后会替换 Godot 版的旧远征存档。",[["选择新的戒律",open_relics],["返回",start_menu]])
	else:open_relics()

func open_relics() -> void:
	show_page("RelicSelection");relic_index=0;render_relic()

func cycle_relic(step: int) -> void:
	relic_index=posmod(relic_index+step,relics.size());render_relic()

func render_relic() -> void:
	var id=relics[relic_index]
	ui("RelicNumber").text="%02d / 09" % (relic_index+1)
	ui("RelicIcon").text=["Ⅰ","Ⅱ","Ⅲ","Ⅳ","Ⅴ","Ⅵ","Ⅶ","Ⅷ","∅"][relic_index]
	ui("RelicIcon").visible=id==""
	ui("RelicObject").visible=id!=""
	if id!="":
		var regions={"R007":Rect2(885,431,265,185),"R008":Rect2(810,32,355,395),"R073":Rect2(883,618,300,198),"R074":Rect2(854,817,321,234),"R075":Rect2(847,1053,310,187),"R076":Rect2(870,1242,295,252),"R077":Rect2(907,1495,236,255),"R078":Rect2(873,1752,295,266)}
		var texture=AtlasTexture.new();texture.atlas=preload("res://art/relics.png");texture.region=regions[id];ui("RelicObject").texture=texture
	ui("RelicName").text=game.cards[id].name if id!="" else "无戒律"
	ui("RelicDescription").text=game.cards[id].description if id!="" else "按基础点数比较胜负。你可以装备六条永久规则。"

func begin_run() -> void:
	game.fresh(relics[relic_index]);game.s.phase="opening_reward";game.offer();game.save()
	show_page("MapScreen")
	if not FileAccess.file_exists("user://tutorial_seen.txt"):
		modal("命运本身", "欢迎来到赌桌。\n\n每回合投掷三次。第一次投掷后，单击骰子锁定或解锁，锁图标表示保留；第三次后揭晓胜负。永久规则自动触发，双方点数差决定伤害。\n\n你的旅程，从第一条规则开始。",[["记住规则 · 选择起始牌",func():
			var file=FileAccess.open("user://tutorial_seen.txt",FileAccess.WRITE);file.store_string("1");show_reward(true)]])
		ui("DialogPortrait").texture=portrait("B003");ui("DialogPortrait").show()
	else:show_reward(true)

func resume_run() -> void:
	if not game.resume():modal("无法继续","没有可用的 Godot 存档，或存档版本不兼容。网页版存档不会被覆盖。",[["返回",start_menu]]);return
	restore_screen()

func restore_screen() -> void:
	match game.s.phase:
		"battle":show_page("BattleHUD");render_battle();update_dice({},false)
		"opening_reward":show_page("MapScreen");show_reward(true)
		"reward":show_page("MapScreen");show_reward(false)
		"shop":show_page("MapScreen");shop()
		"rest":show_page("MapScreen");rest()
		"event":show_page("MapScreen");event()
		"victory":show_page("BattleHUD");render_battle();update_dice({},false);victory()
		_:render_map()

func save_home() -> void:
	if busy:return
	if not game.save():modal("保存失败","无法写入远征存档，请检查磁盘空间。",[["返回",close_dialog]]);return
	show_page("MainMenu")

func render_map() -> void:
	show_page("MapScreen")
	if game.s.phase=="complete":modal("再见一掷","你走过三章赌局，击败了命运本身。\n这一次，你改写了离席的规则。",[["返回首页",func():show_page("MainMenu")]]);return
	var layer=game.s.done.size()
	var chapter=1 if layer<15 else (2 if layer<31 else 3)
	ui("ChapterTitle").text=["第一章\n迷雾赌厅","第二章\n契约回廊","第三章\n终末赌局"][chapter-1]
	ui("RunStats").text="生命 %d / %d\n金币 %d  ·  第 %d / 46 步" % [game.s.hp,game.s.maxHp,game.s.gold,mini(46,layer+1)]
	for c in range(1,4):ui("Chapter%d" % c).visible=c==chapter
	for n in game.map:
		var b=ui("Node_"+n.key.replace("-","_"))
		b.text="？" if chapter==3 and n.l>layer+1 else NAMES[n.type]
		if n.key in game.s.done:b.text="✓ "+NAMES[n.type]
		b.disabled=n.key not in game.s.next
	await get_tree().process_frame
	var chapter_start=[0,15,31][chapter-1]
	ui("MapScroll").scroll_vertical=maxi(0,1540-(layer-chapter_start)*100-470)

func enter_node(n: Dictionary) -> void:
	if n.key not in game.s.next:return
	game.s.current=n.key
	game.s.nodeRewarded=false
	match n.type:
		"fight","elite","boss":
			game.start_battle(game.s.encounters[n.key]);log_lines.clear();last_result={};show_page("BattleHUD");render_battle();update_dice({},false)
		"altar":finish_current()
		"shop":game.s.phase="shop";game.s.shopPurchases=0;game.s.shopRefreshed=false;game.offer();shop()
		"rest":game.s.phase="rest";rest()
		_:game.s.phase="event";event()
	game.save()

func finish_current() -> void:
	for n in game.map:
		if n.key!=game.s.current:continue
		if int(n.l) in [0,1,6,13,20,29,40] and n.type!="boss" and not game.s.get("nodeRewarded",false):
			game.s.nodeRewarded=true;game.s.phase="reward";game.offer();game.save();show_reward(false);return
	game.finish_node();render_map()

func render_battle() -> void:
	var s=game.s
	var enabled=BattleProtocol.enabled(s)
	for name in ["EarlyStop","TacticalButton","PublicPot","PotChips","WagerLabel","SpeedButton"]:ui(name).visible=enabled
	ui("ProtocolButton").disabled=busy
	ui("EarlyStop").disabled=busy or s.roll!=2
	ui("TacticalButton").disabled=busy or s.roll<1 or s.roll>=3 or s.get("earlyStop",false) or s.get("tacticalTokens",0)==0
	ui("TacticalButton").text="战术筹码 %d · 骰面 +1"%s.get("tacticalTokens",0)
	ui("PublicPot").text="公共赌注 %d"%s.get("publicPot",0)
	ui("PotChips").text="◈ ".repeat(int(s.get("publicPot",0))/2)
	ui("WagerLabel").text="本轮赌局 · "+BattleProtocol.wager(s).get("name","")+"\n"+{"overwhelm":"有效领先 ≥4 获胜：额外伤害 +3","initiative":"第二掷提前收手并获胜：下轮护盾 +2","steal":"赌注 ≥4 并获胜：额外伤害 +2","narrow":"有效领先 1–3 获胜：战术筹码 +1"}.get(s.get("currentWager",""),"")
	ui("EnemyPortrait").texture=portrait(s.enemy.id)
	ui("HealthLabel").text="远征者  %d / %d                 护盾 %d  /  %d                 %s  %d / %d" % [s.hp,s.maxHp,last_result.get("playerShield",0),last_result.get("enemyShield",0),s.enemy.name,s.enemy.hp,s.enemy.maxHp]
	ui("SharedHealth").value=100.0*(float(s.hp)/s.maxHp)/maxf(.001,float(s.hp)/s.maxHp+float(s.enemy.hp)/s.enemy.maxHp)
	ui("RoundLabel").text="回合 %02d · %d / 3 掷" % [s.roundNumber,s.roll]
	ui("IntentLabel").text=" · ".join(PackedStringArray(s.enemyIntent.lines))
	ui("PlayerTotal").text="你的点数：%s" % (str(RulesEngine.total(s.pdice)) if s.roll else "—")
	ui("EnemyTotal").text="对手点数：%s" % (str(RulesEngine.total(s.edice)) if s.roll else "—")
	ui("RollButton").disabled=busy or s.get("earlyStop",false) or s.roll>=3 or (s.enemyIntent.tax and not s.enemyMemory.has("tax"))
	ui("SettleButton").disabled=busy or s.roll!=3
	ui("BattleMenu").disabled=busy
	for i in range(3):
		var b=ui("LockButtons").get_child(i);b.disabled=busy or s.roll==0 or s.roll>=3 or s.enemyIntent.seal==i
		b.text=("已锁定" if s.locked[i] else "锁骰")+" %d" % (i+1)
		$Tavern/PlayerDice.get_child(i).set_locked(s.locked[i])
	for i in range(6):
		var b=ui("RuleSlots").get_child(i)
		b.disabled=busy or i>=s.rules.size()
		b.text=game.cards[s.rules[i]].name if i<s.rules.size() else "空规则位"
		b.tooltip_text=game.cards[s.rules[i]].description if i<s.rules.size() else ""
	clear_children(ui("EnemyActions"))
	if s.roll==0:
		if s.enemyIntent.tax and not s.enemyMemory.has("tax"):
			enemy_button("支付 6 金币 · 解除强化","pay",s.gold<6);enemy_button("拒付 · 胜利多得 8 金币","refuse")
		if s.enemyIntent.wager and s.enemyMemory.get("wagerRound",0)!=s.roundNumber:enemy_button("主动加注 · 双方伤害翻倍","wager")
		if s.enemyIntent.thrift and s.enemyMemory.get("thriftRound",0)!=s.roundNumber:enemy_button("支付 4 金币 · 本回合护盾 +2","thrift",s.gold<4)
	ui("BattleLog").text="\n".join(log_lines)

func portrait(id: String) -> AtlasTexture:
	var rc=portrait_regions.get(id,[0,0])
	var width=149.4 if rc[0]==2 else 124.5
	var texture=AtlasTexture.new()
	texture.atlas=preload("res://art/enemy_portraits.png")
	texture.region=Rect2(23+rc[1]*width,[225,505,784][int(rc[0])],width-8,[152,151,147][int(rc[0])])
	return texture

func enemy_button(text: String, kind: String, disabled: bool=false) -> void:
	var b=preload("res://scenes/ui/ChoiceButton.tscn").instantiate();b.text=text;b.disabled=disabled or busy
	b.pressed.connect(func():if not busy and game.enemy_choice(kind):game.save();render_battle())
	ui("EnemyActions").add_child(b)

func toggle_lock(i: int) -> void:
	if not busy and game.lock_die(i):
		$CabaretAudio.play("Click");game.save();render_battle()

func update_dice(masks: Dictionary, animate: bool) -> void:
	for i in range(3):
		var die=$Tavern/PlayerDice.get_child(i)
		var values=game.s.faces[i].duplicate()
		# Temporary transformations change only the displayed physical face this roll.
		values[int(game.s.physical[i])]=game.s.pdice[i]
		die.set_values(values);die.roll_duration=.40/animation_speed
		if masks.is_empty() or masks.pm[i]:die.roll_to(game.s.physical[i],animate)
		var enemy=$Tavern/EnemyDice.get_child(i);enemy.visible=i<game.s.edice.size()
		if enemy.visible:
			enemy.roll_duration=.40/animation_speed
			if masks.is_empty() or masks.em[i]:enemy.roll_to(game.s.enemyPhysical[i],animate)

func roll_dice() -> void:
	if busy:return
	var masks=game.roll()
	if masks.is_empty():return
	busy=true;ui("SettlementText").text="";render_battle();update_dice(masks,true)
	ui("PlayerTotal").text="骰子滚动中…";ui("EnemyTotal").text="…"
	await get_tree().create_timer(.85/animation_speed).timeout
	busy=false
	log_lines.append("第 %d 掷：你 %s / 对手 %s" % [game.s.roll,str(game.s.pdice),str(game.s.edice)])
	game.save();render_battle()

func settle_round() -> void:
	if busy or (game.s.roll!=3 and not (BattleProtocol.enabled(game.s) and game.s.get("earlyStop",false))):return
	busy=true;render_battle()
	var rule_ids=game.s.rules.duplicate()
	var experimental=BattleProtocol.enabled(game.s)
	var result=game.settle()
	if result.is_empty():busy=false;return
	last_result=result
	for line in result.lines:log_lines.append(line)
	log_lines.append("最终 %d : %d · %s %d 伤害" % [result.p,result.e,"造成" if result.win else "受到",result.diff])
	while log_lines.size()>40:log_lines.remove_at(0)
	ui("BattleLog").text="\n".join(log_lines)
	game.save() # Commit once before any animation; skipping cannot repeat a reward.
	if experimental:await $SettlementPresenter.play_result(result,rule_ids)
	else:
		ui("PlayerTotal").text="结算：%d" % result.p;ui("EnemyTotal").text="结算：%d" % result.e
		await get_tree().create_timer(.65/animation_speed).timeout
	busy=false
	if game.s.phase=="defeat":modal("此行止步于此","赌局结束。下一次，走一条不同的路。",[["返回首页",func():show_page("MainMenu")]]);return
	if game.s.phase=="victory":game.save();victory();return
	game.save();render_battle()

func victory() -> void:
	modal("赌局胜出","击败 %s，获得金币并恢复生命。\n剩余生命 %d / %d · 金币 %d" % [game.s.enemy.name,game.s.hp,game.s.maxHp,game.s.gold],[["继续远征",func():
		finish_current()]])

func show_reward(opening: bool) -> void:
	var options=[]
	for id in game.s.reward:
		var c=game.cards[id]
		options.append([c.name+"\n"+c.description,func():take_card(id,opening)])
	options.append(["放弃规则 · 领取 8 金币",func():game.s.gold+=8;finish_reward(opening)])
	modal("选择一条永久规则","规则自动生效。相邻卡牌的顺序会影响部分联动。",options)

func take_card(id: String, opening: bool, price: int=0) -> void:
	if id in game.s.rules:return
	var supports=game.s.rules.filter(func(k):return game.cards[k].slot=="support")
	var conflicts=game.s.rules.filter(func(k):return game.cards[id].get("exclusive_group",null)!=null and game.cards[id].get("exclusive_group","")!="" and game.cards[k].get("exclusive_group",null)==game.cards[id].exclusive_group)
	var replace=conflicts if not conflicts.is_empty() else (supports if supports.size()>=game.capacity() else [])
	if not replace.is_empty():
		var choices=[]
		for old in replace:choices.append(["替换 "+game.cards[old].name,func():
			if price>0 and not game.spend(price):return
			game.s.rules.erase(old);game.s.rules.append(id);card_acquired(id,opening,price)])
		choices.append(["取消",func():shop() if price>0 else show_reward(opening)])
		modal("选择替换的规则",game.cards[id].description,choices);return
	if price>0 and not game.spend(price):return
	game.s.rules.append(id);card_acquired(id,opening,price)

func card_acquired(id: String, opening: bool, price: int) -> void:
	if price>0:
		game.s.shopPurchases+=1;game.s.reward.erase(id);game.save();shop()
	else:finish_reward(opening)

func finish_reward(opening: bool) -> void:
	if opening:game.s.phase="map";game.s.reward=[];game.save()
	else:finish_current();return
	render_map()

func shop() -> void:
	var options=[]
	for id in game.s.reward:
		var c=game.cards[id]
		var price=maxi(1,int(c.price)-(5 if game.has("shop_discount") and game.s.shopPurchases==0 else 0))
		options.append(["%d 金币 · %s\n%s" % [price,c.name,c.description],func():take_card(id,false,price),game.s.gold<price or game.s.shopPurchases>=2])
	options.append(["刷新货架 · 5 金币",func():if game.spend(5):game.s.shopRefreshed=true;game.offer();game.save();shop(),game.s.get("shopRefreshed",false) or game.s.gold<5])
	options.append(["离开",finish_current])
	modal("行旅商人","金币 %d · 最多购买两张，可付 5 金币刷新一次。" % game.s.gold,options)

func rest() -> void:
	var price=25-(8 if game.has("rest_discount") else 0)
	var upgrade_price=35-(8 if game.has("rest_discount") else 0)
	modal("炉火未熄","温暖的炉火，足够让你再走一程。",[["休息 · 恢复 8 生命",func():game.s.hp=mini(game.s.maxHp,game.s.hp+8);finish_current()],["%d 金币 · 恢复全部生命" % price,func():if game.spend(price):game.s.hp=game.s.maxHp;finish_current(),game.s.gold<price],["%d 金币 · 首骰的 1 永久改为 3" % upgrade_price,func():if game.spend(upgrade_price):game.s.faces[0][0]=3;finish_current(),game.s.faces[0][0]==3 or game.s.gold<upgrade_price],["离开",finish_current]])

func event() -> void:
	modal("雾中的许愿井","一枚旧金币悬在井沿。井底的声音提出了交易。",[["献出 5 生命 · 获得永久规则",func():game.s.hp-=5;game.s.phase="reward";game.offer();game.save();show_reward(false),game.s.hp<=5],["打捞钱袋 · 获得 18 金币",func():game.s.gold+=18;finish_current()],["饮下清泉 · 恢复 4 生命",func():game.s.hp=mini(game.s.maxHp,game.s.hp+4);finish_current()]])

func collection() -> void:
	var lines: PackedStringArray=[]
	for id in game.s.rules:lines.append("[b]%s[/b]  %s" % [game.cards[id].name,game.cards[id].description])
	for i in range(3):lines.append("骨骰 %d 六面：%s" % [i+1,str(game.s.faces[i])])
	modal("行囊与骰面","\n\n".join(lines),[["返回",close_dialog]])

func enemy_details() -> void:
	modal(game.s.enemy.name,game.s.enemy.desc+"\n\n"+"\n".join(PackedStringArray(game.s.enemyIntent.lines)),[["返回赌桌",close_dialog]])

func rulebook() -> void:
	modal("远征规则","[b]三掷一决[/b]\n每回合投掷三次，首掷后可以锁骰。揭晓时按戒律与永久规则计算双方最终点数，差值造成伤害。\n\n[b]构筑[/b]\n一条主戒律 + 五条规则，或无戒律 + 六条规则。\n\n[b]远征[/b]\n三章节分支地图，沿连线前进。生命归零结束；击败第三章首领完成远征。\n\n每次操作自动保存。Godot 存档独立于网页版。",[["查看 80 张规则",catalog],["返回",close_dialog]])

func catalog() -> void:
	var options=[]
	for c in game.cards.values():options.append([c.id+" · "+c.name,func():modal(c.name,c.description,[["回到图鉴",catalog],["关闭",close_dialog]])])
	options.append(["关闭",close_dialog]);modal("规则图鉴","共 80 张规则，沿用网页版卡牌数据。",options)

func settings() -> void:
	modal("幕后台", "画面与声音",[
		["背景音乐："+("开" if $CabaretAudio.music_enabled else "关"),func():$CabaretAudio.toggle_music();settings()],
		["按键音效："+("开" if $CabaretAudio.effects_enabled else "关"),func():$CabaretAudio.toggle_effects();settings()],
		["黑白像素滤镜："+("开" if $CabaretFilter.visible else "关"),func():$CabaretFilter.visible=not $CabaretFilter.visible;settings()],
		["赌桌协议实验 / 调试",protocol_debug],
		["标准投掷速度",func():animation_speed=1.0],
		["快速投掷",func():animation_speed=2.5],
		["切换全屏",func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)],
		["返回",close_dialog]])

func show_rule_slot(index: int) -> void:
	if index>=game.s.rules.size():return
	var c=game.cards[game.s.rules[index]]
	modal(c.name,c.description,[["返回赌桌",close_dialog]])


func cycle_settlement_speed() -> void:
	$SettlementPresenter.speed=($SettlementPresenter.speed+1)%3
	ui("SpeedButton").text="结算："+["正常","快速","跳过"][$SettlementPresenter.speed]
	if $SettlementPresenter.speed==2:$SettlementPresenter.skip()

func tactical_menu() -> void:
	if busy:return
	var options=[]
	for i in range(3):options.append(["第 %d 骰：%d → %d"%[i+1,game.s.pdice[i],mini(6,game.s.pdice[i]+1)],func():
		if game.use_tactical(i):game.save();update_dice({},false);render_battle(),game.s.pdice[i]>=6])
	options.append(["返回",close_dialog]);modal("使用战术筹码","消耗 1 枚，只改变本轮当前骰面。",options)

func protocol_debug() -> void:
	if busy:return
	var active=not game.s.is_empty() and game.s.get("phase","")=="battle"
	var enabled=BattleProtocol.enabled(game.s) if not game.s.is_empty() else game.battle_experiment_enabled
	var options=[]
	options.append(["赌桌协议："+("开启" if enabled else "关闭"),func():
		game.battle_experiment_enabled=not enabled
		if not game.s.is_empty():
			game.s.battle_experiment_enabled=not enabled
			if enabled:game.s.carryShield=maxi(0,game.s.get("carryShield",0)-game.s.get("protocolShield",0));game.s.protocolShield=0
			game.s.publicPot=0;game.s.tacticalTokens=0;game.s.debugTie=false;game.s.debugClimax=false
			if active:game.s.currentWager=BattleProtocol.choose(game.s);render_battle()
			game.save()
		protocol_debug(),active and game.s.roll!=0])
	if active and enabled:
		options.append(["敌人赌局：自动按池轮换",func():game.s.debugWager="";game.s.currentWager=BattleProtocol.choose(game.s);render_battle();protocol_debug()])
		for id in BattleProtocol.config.wagers:
			options.append(["指定赌局 · "+BattleProtocol.config.wagers[id].name,func():game.s.debugWager=id;game.s.currentWager=id;render_battle();protocol_debug()])
		for amount in range(0,int(BattleProtocol.config.pot_cap)+1,int(BattleProtocol.config.pot_step)):options.append(["公共赌注设为 %d"%amount,func():game.s.publicPot=amount;render_battle();protocol_debug()])
		options.append(["下一次比较强制同分（保留平局判胜）",func():game.s.debugTie=true;close_dialog()])
		options.append(["下一次强制演出爆发（不加伤害）",func():game.s.debugClimax=true;close_dialog()])
	options.append(["结算速度："+["正常","快速","跳过"][$SettlementPresenter.speed],func():cycle_settlement_speed();protocol_debug()])
	options.append(["查看上次实际事件",show_settlement_events])
	options.append(["返回",close_dialog])
	modal("赌桌协议 1.0 · 实验调试","开关默认关闭，仅可在回合投骰前切换。切换时清空实验筹码。调试同分与强制爆发为一次性。",options)

func show_settlement_events() -> void:
	var lines: PackedStringArray=[]
	for e in last_result.get("events",[]):lines.append("%s · %s · %s: %s %+d → %s"%[e.type,e.source_rule_id,e.resource,str(e.before),int(e.delta),str(e.after)])
	modal("实际结算事件", "\n".join(lines) if not lines.is_empty() else "尚未结算。",[["返回",protocol_debug]])
