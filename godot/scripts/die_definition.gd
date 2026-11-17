@tool
class_name DieDefinition
extends Resource

## The physical six faces. Duplicate this resource to author a custom die.
@export var face_values: Array[int] = [1, 2, 3, 4, 5, 6]:
	set(value):
		face_values=value
		emit_changed()
## Empty means number pips. Supported visual IDs: fire, critical.
@export var face_symbols: PackedStringArray = ["", "", "", "", "", ""]:
	set(value):
		face_symbols=value
		emit_changed()

func valid() -> bool:
	return face_values.size() == 6 and face_symbols.size() == 6
