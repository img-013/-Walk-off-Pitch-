extends SceneTree
func _initialize():call_deferred("check")
func check():
	var app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	await process_frame
	var audio=app.get_node("CabaretAudio")
	assert(audio.get_node("Music").stream.loop)
	for key in ["Music","Hover","Click","Roll","Reveal"]:
		var stream=audio.get_node(key).stream
		assert(stream.get_length()>0.05)
		print(key, " duration=",stream.get_length())
	assert(app.ui("StartButton").has_meta("cabaret_audio"))
	app.start_menu()
	assert(app.ui("ChoiceButtons").get_child(0).has_meta("cabaret_audio"))
	assert(app.get_node("CabaretFilter/MonochromePixels").mouse_filter==2)
	assert(app.get_node("Tavern/Cabaret").get_child_count()>0)
	print("PRESENTATION OK: music loop, five streams, static and dynamic button sound bindings, click-through filter, imported scene.")
	app.queue_free();await process_frame;quit()
