extends Node
## Read-only presentation. No access to RunState.settle(), resource awards, or RNG.
@export_enum("正常","快速","跳过") var speed: int = 0
@export var trigger_sound: AudioStream = preload("res://audio/click.wav")
@export var climax_sound: AudioStream = preload("res://audio/reveal.wav")
@export var impact_sound: AudioStream = preload("res://audio/protocol_impact.wav")
var playing=false
var skip_requested=false
var shown_events: Array=[]
var app: Node
var tone=0

func skip() -> void:
	skip_requested=true

func play_result(result: Dictionary, rule_ids: Array) -> void:
	if playing:return
	playing=true;skip_requested=speed==2;tone=0;shown_events=[]
	app=get_parent()
	app.ui("SkipSettlement").visible=true
	var events: Array=result.events.duplicate(true)
	var cfg=BattleProtocol.config.presentation
	var normal=minf(cfg.normal_step+cfg.pause,float(cfg.max_duration)/maxi(1,events.size()+2))
	var step=normal*(cfg.fast_scale if speed==1 else 1.0)
	var deadline=Time.get_ticks_msec()+int(float(cfg.max_duration)*1000)
	for ev in events:
		if Time.get_ticks_msec()>=deadline:skip_requested=true
		shown_events.append(ev.duplicate(true))
		if not ev.animate or skip_requested:continue
		var card: Control=null
		var index=rule_ids.find(ev.source_rule_id)
		if index>=0:card=app.ui("RuleSlots").get_child(index)
		if ev.type in ["RULE_TRIGGER","CORE_RULE_TRIGGER"]:
			tone+=1
			var title=app.game.cards.get(ev.source_rule_id,{}).get("name","")
			app.ui("Contribution").text="%s · %s %s%d"%[title,ev.label,"+" if ev.delta>0 else "",ev.delta]
			app.ui("Contribution").add_theme_font_size_override("font_size",32 if app.ui("Contribution").text.length()<23 else 24)
			sound(false)
		elif ev.type=="CLIMAX_EVENT":
			app.ui("Contribution").text="钉子一刻 · "+ev.label
			await pause(float(cfg.climax_pause))
			sound(true)
		else:
			if ev.sound=="chip":sound(false)
			app.ui("SettlementText").text=ev.label+(" %d"%ev.after if ev.resource in ["damage","pot","gap"] else "")
		var label=app.ui(ev.ui_element)
		var table=app.get_node("Tavern/Cabaret/DiceTable")
		var home=table.position
		var enemy=app.get_node_or_null("Tavern/EnemyIdle")
		var enemy_home=enemy.position if enemy else Vector3.ZERO
		var chips=app.ui("PotChips");var chips_home=chips.position
		var burst=ev.type=="FINAL_DAMAGE" and result.climax_event.active
		var hp_bar=app.ui("EnemyHealth" if result.win else "PlayerHealth")
		var hp_before=float(hp_bar.value)
		var hp_after=100.0*app.game.s.enemy.hp/app.game.s.enemy.maxHp if result.win else 100.0*app.game.s.hp/app.game.s.maxHp
		if ev.type=="FINAL_DAMAGE":app.ui("SettlementText").text=("造成" if result.win else "受到")+"  %d  点伤害"%result.diff if result.win or result.lost else "平局"
		var elapsed=0.0
		while elapsed<step and not skip_requested:
			elapsed+=get_process_delta_time()
			var t=clampf(elapsed/step,0,1);var pulse=sin(t*PI)
			if card:
				app.ui("CardGlow").visible=true
				app.ui("CardGlow").position=card.global_position-app.ui("BattleHUD").global_position
				app.ui("CardGlow").size=card.size
				app.ui("CardGlow").modulate.a=pulse
				card.pivot_offset=card.size/2;card.scale=Vector2.ONE*(1.0+float(cfg.card_scale)*pulse)
				card.modulate=Color.WHITE.lerp(Color(1.5,1.35,1.3),pulse)
				card.rotation=sin(t*TAU*2)*float(cfg.card_shake)*pulse
			if ev.resource=="score" and label is Label:
				label.text=("敌方 " if ev.ui_element=="EnemyTotal" else "你的点数 ")+str(roundi(lerpf(ev.before,ev.after,1-pow(1-t,3))))
			if ev.type=="PUBLIC_POT_ADD":chips.position=chips_home+Vector2(0,-float(cfg.chip_drop)*(1-t));chips.text="◈ ".repeat(int(result.potAfter)/2)
			if ev.type=="PUBLIC_POT_PAYOUT":chips.position=chips_home+Vector2(0,float(cfg.chip_flight) if result.win else -float(cfg.chip_flight))*t;chips.modulate.a=1-t
			if ev.type=="FINAL_DAMAGE":
				hp_bar.value=lerpf(hp_before,hp_after,1-pow(1-t,3))
				app.ui("SettlementText").pivot_offset=app.ui("SettlementText").size/2
				app.ui("SettlementText").scale=Vector2.ONE*(1+pulse*(float(cfg.climax_scale) if burst else float(cfg.damage_scale)))
				if burst:
					table.position=home+Vector3(sin(t*TAU*3)*float(cfg.table_shake)*pulse,0,0)
					app.ui("TableFlash").color.a=float(cfg.flash_alpha)*pulse
					if enemy and result.win:enemy.position=enemy_home+Vector3(0,0,-float(cfg.enemy_recoil)*pulse)
					for i in range(rule_ids.size()):
						if app.game.cards[rule_ids[i]].slot=="core":app.ui("RuleSlots").get_child(i).modulate=Color.WHITE.lerp(Color(1.6,1.1,1.1),pulse)
			await get_tree().process_frame
		app.ui("CardGlow").hide()
		if card:card.scale=Vector2.ONE;card.rotation=0;card.modulate=Color.WHITE
		table.position=home
		if enemy:enemy.position=enemy_home
		chips.position=chips_home;chips.modulate=Color.WHITE
		app.ui("TableFlash").color.a=0;app.ui("SettlementText").scale=Vector2.ONE
		if ev.type=="FINAL_DAMAGE":hp_bar.value=hp_after
	# Skip and normal paths end at the same authoritative snapshot.
	app.ui("PlayerTotal").text="结算：%d"%result.p;app.ui("EnemyTotal").text="结算：%d"%result.e
	app.ui("SettlementText").text=""
	app.ui("PublicPot").text="公共赌注 %d"%result.potAfter
	app.ui("PotChips").text="◈ ".repeat(int(result.potAfter)/2)
	app.ui("Contribution").text=""
	for card in app.ui("RuleSlots").get_children():card.modulate=Color.WHITE;card.scale=Vector2.ONE;card.rotation=0
	app.get_node("CabaretAudio/Click").pitch_scale=1.0;app.get_node("CabaretAudio/Reveal").pitch_scale=1.0
	app.ui("SkipSettlement").visible=false;playing=false

func pause(seconds: float) -> void:
	var elapsed=0.0
	while elapsed<seconds and not skip_requested:elapsed+=get_process_delta_time();await get_tree().process_frame

func sound(climax: bool) -> void:
	if not app.get_node("CabaretAudio").effects_enabled:return
	var player=app.get_node("CabaretAudio/Reveal" if climax else "CabaretAudio/Click")
	player.stream=climax_sound if climax else trigger_sound
	var cfg=BattleProtocol.config.presentation
	player.pitch_scale=cfg.climax_pitch if climax else minf(cfg.max_pitch,1.0+tone*cfg.pitch_step)
	player.volume_db=app.get_node("CabaretAudio").effects_volume_db+(2 if climax else -2)
	player.play()
	if climax:
		$Impact.stream=impact_sound;$Impact.volume_db=app.get_node("CabaretAudio").effects_volume_db;$Impact.play()
