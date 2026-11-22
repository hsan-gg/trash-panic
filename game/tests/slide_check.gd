extends SceneTree
## Workers must not snag on station corners: walking straight at a one-tile gap between two solid tiles, from
## anywhere up to half a tile off-centre, the worker slips around the corner and through the gap.

const OFFSETS := [0.0, 0.3, 0.55, 0.7, 0.9]


func _initialize() -> void:
	Controls.register_actions()
	var root := Node3D.new()
	get_root().add_child(root)
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	gs.shape = WorldBoundaryShape3D.new()
	ground.add_child(gs)
	root.add_child(ground)
	for x in [-RoomMap.TILE, RoomMap.TILE]:  # two solid tiles with a one-tile gap between them
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(RoomMap.TILE, 2, RoomMap.TILE)
		cs.shape = s
		b.add_child(cs)
		b.position = Vector3(x, 0.6, 0)
		root.add_child(b)
	var stuck := []
	Input.action_press("move_forward")
	for x in OFFSETS:
		var p := Player.new()
		p.frozen = false
		root.add_child(p)
		p.avatar.setup(0)
		p.global_position = Vector3(x, 0, 1.6)
		for i in 90:
			await physics_frame
		if p.global_position.z > -0.9:
			stuck.append("%.2f (z=%.2f)" % [x, p.global_position.z])
		p.free()
	print("slide: stuck at offsets %s" % [stuck] if not stuck.is_empty() else "slide: ok")
	quit(0)
