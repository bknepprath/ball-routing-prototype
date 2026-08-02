extends Node3D

var entry_port: Marker3D
var exit_port: Marker3D

func _init() -> void:
	entry_port = Marker3D.new()
	entry_port.name = "Entry"
	add_child(entry_port)
	exit_port = Marker3D.new()
	exit_port.name = "Exit"
	add_child(exit_port)

func set_exit(local_position: Vector3, local_rotation: Vector3 = Vector3.ZERO) -> void:
	exit_port.position = local_position
	exit_port.rotation = local_rotation

func chain_to(next_attachment: Node3D) -> void:
	next_attachment.global_transform = exit_port.global_transform * next_attachment.get_node("Entry").transform.affine_inverse()
