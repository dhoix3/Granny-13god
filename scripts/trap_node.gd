class_name TrapNode
extends Node3D

var jaw_l: Node3D
var jaw_r: Node3D

func _ready() -> void:
	pass

func set_armed(armed: bool) -> void:
	if jaw_l == null or jaw_r == null:
		return
	var target := 0.0 if armed else 1.0
	jaw_l.rotation.z = lerpf(jaw_l.rotation.z, -0.55 + target * 0.55, 0.25)
	jaw_r.rotation.z = lerpf(jaw_r.rotation.z, 0.55 - target * 0.55, 0.25)
