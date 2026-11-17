extends SceneTree
func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game=RunState.new()
	var cases=JSON.parse_string(FileAccess.get_file_as_string("res://tests/parity.json"))
	var failures=0
	for test in cases:
		var actual=RulesEngine.evaluate(test.state,game.cards)
		for key in test.expected:
			if actual[key]!=test.expected[key]:
				failures+=1
				if failures<25:print("MISMATCH ",test.name," ",key," expected=",test.expected[key]," actual=",actual[key])
	game.fresh("",100)
	game.start_battle("E001")
	for i in range(3):game.roll()
	assert(game.s.roll==3)
	assert(game.roll().is_empty())
	assert(not game.settle().is_empty())
	var instance=load("res://scenes/dice.tscn").instantiate()
	root.add_child(instance)
	for i in range(6):
		instance.roll_to(i,false)
		var normal=instance.get_node("DiceBody/Face%d" % i).global_transform.basis.z
		assert(normal.dot(Vector3.UP)>.99,"Physical face orientation mismatch")
	var other=load("res://scenes/dice.tscn").instantiate()
	root.add_child(other)
	instance.change_face(0,6,"fire")
	assert(instance.definition.face_values[0]==6 and other.definition.face_values[0]==1,"Die resources must stay independent")
	other.free()
	instance.free()
	print("PARITY: ",cases.size()," cases, ",failures," differences; three-roll lifecycle and six physical face orientations checked.")
	quit(1 if failures else 0)
