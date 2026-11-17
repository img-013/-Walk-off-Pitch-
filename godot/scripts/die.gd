@tool
extends Node3D

@export var definition: DieDefinition:
	set(value):
		if definition and definition.changed.is_connected(update_faces):definition.changed.disconnect(update_faces)
		definition=value
		if definition and not definition.changed.is_connected(update_faces):definition.changed.connect(update_faces)
		if is_node_ready():update_faces()
@export_range(0.1, 2.0) var roll_duration: float = 0.72
@export_range(0.05, 1.5) var bounce_height: float = 0.23
var tween: Tween
var home: Vector3
const ROTATIONS = [Vector3.ZERO, Vector3(-PI/2,0,0), Vector3(0,0,PI/2), Vector3(0,0,-PI/2), Vector3(PI/2,0,0), Vector3(PI,0,0)]

func _ready() -> void:
	home = position
	update_faces()

func update_faces() -> void:
	if not is_node_ready() or definition == null or not definition.valid(): return
	var body = StandardMaterial3D.new()
	body.albedo_texture = preload("res://art/bone.svg")
	body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	body.roughness = 1.0
	$DiceBody/Mesh.material_override = body
	for i in range(6):
		var material = StandardMaterial3D.new()
		var symbol = definition.face_symbols[i]
		var file = "res://art/%s.svg" % (symbol if symbol in ["fire", "critical"] else "face_%d" % clampi(definition.face_values[i],1,6))
		material.albedo_texture = load(file)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.roughness = 1.0
		get_node("DiceBody/Face%d" % i).material_override = material

func change_face(index: int, value: int, symbol: String = "") -> void:
	if index < 0 or index > 5 or value < 1 or value > 6: return
	definition = definition.duplicate(true)
	definition.face_values[index] = value
	definition.face_symbols[index] = symbol
	update_faces()

func set_values(values: Array) -> void:
	definition = definition.duplicate(true)
	definition.face_values.assign(values)
	update_faces()

## Receives a PHYSICAL face index from the game, never draws random numbers.
func roll_to(face_index: int, animate: bool = true) -> void:
	if tween: tween.kill()
	var target = ROTATIONS[clampi(face_index,0,5)]
	if not animate:
		$DiceBody.rotation = target
		position = home
		return
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($DiceBody,"rotation", target + Vector3(TAU*2,TAU,0),roll_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"position:y",home.y+bounce_height,roll_duration*.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self,"position:y",home.y,roll_duration*.62).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): $DiceBody.rotation = target)

func set_locked(locked: bool) -> void:
	var mat = $DiceBody/Mesh.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(0.65,0.85,0.55) if locked else Color.WHITE
