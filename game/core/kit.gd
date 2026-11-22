class_name Kit
extends RefCounted
## Level-building helpers: Kenney models with collision made from their own meshes, and chunky solid blocks.

const MODELS := "res://core/assets/3d/%s/%s.glb"

static var _shapes := {}
static var _materials := {}


static func model(pack: String, model_name: String) -> Node3D:
	return load(MODELS % [pack, model_name]).instantiate()


## A static prop. `shape` is "mesh" (exact, for walkable pieces), "box" (cheap) or "none" (decoration).
static func prop(parent: Node3D, pack: String, model_name: String, pos: Vector3, yaw_deg := 0.0, scl := 1.0, shape := "box") -> Node3D:
	var m := model(pack, model_name)
	var root: Node3D = m if shape == "none" else StaticBody3D.new()
	if shape != "none":
		root.add_child(m)
		add_collision(root, m, pack + model_name + shape, shape == "mesh")
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	root.scale = Vector3.ONE * scl
	parent.add_child(root)
	return root


## Collision for `body` from the meshes under `model` (cached per model).
static func add_collision(body: Node3D, model_root: Node3D, key: String, exact: bool) -> void:
	if not _shapes.has(key):
		var shapes := []
		for mi: MeshInstance3D in model_root.find_children("*", "MeshInstance3D", true, false):
			var xf := model_root.global_transform.affine_inverse() * mi.global_transform if model_root.is_inside_tree() else _relative(mi, model_root)
			if exact:
				shapes.append([mi.mesh.create_trimesh_shape(), xf])
			else:
				var box := BoxShape3D.new()
				var aabb := mi.mesh.get_aabb()
				box.size = aabb.size.max(Vector3.ONE * 0.05)
				shapes.append([box, xf * Transform3D(Basis(), aabb.get_center())])
		_shapes[key] = shapes
	for s in _shapes[key]:
		var cs := CollisionShape3D.new()
		cs.shape = s[0]
		cs.transform = s[1]
		body.add_child(cs)


## A solid box: the walkable ground of the course. `top` colours the top face area, the sides stay dark.
static func block(parent: Node3D, center: Vector3, size: Vector3, color: Color, body: PhysicsBody3D = null) -> PhysicsBody3D:
	var b: PhysicsBody3D = body if body else StaticBody3D.new()
	shape_box(b, size, color)
	b.position = center
	parent.add_child(b)
	return b


## A coloured box mesh with matching collision, added straight to an existing body (e.g. a Mover).
static func shape_box(body: PhysicsBody3D, size: Vector3, color: Color, offset := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material(color)
	mi.position = offset
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = offset
	body.add_child(cs)


static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_materials[color] = m
	return _materials[color]


static func _relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D()
	var n: Node = node
	while n and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
