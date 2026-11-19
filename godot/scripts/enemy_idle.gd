@tool
extends Node3D
func _ready() -> void:
	var material=$Portrait.material_override as ShaderMaterial
	material=material.duplicate()
	$Portrait.material_override=material
	if Engine.is_editor_hint():
		material.set_shader_parameter("video_texture",preload("res://video/thief-preview.png"))
	else:
		material.set_shader_parameter("video_texture",$VideoViewport.get_texture())
		$VideoViewport/IdleVideo.play()
