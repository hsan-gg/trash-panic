class_name Bake
extends RefCounted
## Merges many flat-coloured primitive meshes (boxes, cylinders...) into one vertex-coloured mesh: one draw call
## instead of hundreds, which phones need. Only plain opaque Kit.material colours are merged; anything else
## (textures, glow, transparency, shaders) is left alone.

static var _material: StandardMaterial3D


## Merge the mergeable MeshInstance3D children of `parent` (not deeper), skipping `keep`. Returns the merged node.
static func children(parent: Node3D, keep: Array = []) -> MeshInstance3D:
	var parts: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if child is MeshInstance3D and child not in keep and mergeable(child):
			parts.append(child)
	if parts.size() < 2:
		return null
	var merged := MeshInstance3D.new()
	merged.mesh = mesh_of(parts, parent)
	merged.material_override = material()
	parent.add_child(merged)
	for p in parts:
		p.queue_free()
	return merged


static func mergeable(mi: MeshInstance3D) -> bool:
	var m := mi.material_override as StandardMaterial3D
	return mi.mesh is PrimitiveMesh and m != null and not m.emission_enabled and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and m.albedo_texture == null


## One ArrayMesh from `parts`, in `space`'s coordinates (parts may sit deeper under it), coloured per part.
static func mesh_of(parts: Array[MeshInstance3D], space: Node3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mi in parts:
		var xf := _relative(mi, space)
		var normal_basis := xf.basis.inverse().transposed()  # correct normals under non-uniform scale
		var color: Color = (mi.material_override as StandardMaterial3D).albedo_color
		var arrays := mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var order: Array = range(verts.size()) if idx.is_empty() else Array(idx)
		for i in order:
			st.set_color(color)
			st.set_normal((normal_basis * normals[i]).normalized())
			st.add_vertex(xf * verts[i])
	return st.commit()


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.85
	return _material


static func _relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D()
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
