extends Light3D
@export_range(0.0,0.15) var strength: float = 0.045
@export var phase: float = 0.0
var baseline: float
var clock: float = 0.0
func _ready() -> void:
	baseline=light_energy
func _process(delta: float) -> void:
	clock+=delta
	light_energy=baseline*(1.0+strength*(sin(clock*3.7+phase)+0.35*sin(clock*8.3+phase*2.0)))
