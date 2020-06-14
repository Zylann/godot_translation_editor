tool

static func is_in_edited_scene(node: Node) -> bool:
	if not node.is_inside_tree():
		return false
	var edited_scene = node.get_tree().edited_scene_root
	if node == edited_scene:
		return true
	return edited_scene != null and edited_scene.is_a_parent_of(node)
