extends Spatial

var vault = load("res://Vault.tscn")
var tile_block = load("res://TileBlock.tscn")
var tile_count = 33
var attach_point = Vector3(0,0,0)
var attach_point2
func _ready():
	for tile in tile_count:
		var new_tile = tile_block.instance()
		add_child(new_tile)
		new_tile.global_transform.origin = attach_point
		attach_point = new_tile.get_node("AttachPoint").global_transform.origin
		if tile in [7, 13]:
			new_tile.rotate_y(1)
			attach_point2 = new_tile.get_node("AttachPoint").global_transform.origin
			for tile2 in tile_count:
				var new_tile2 = tile_block.instance()
				add_child(new_tile2)
				new_tile2.global_transform.origin = attach_point2
				new_tile2.rotate_y(1)
				attach_point2 = new_tile2.get_node("AttachPoint").global_transform.origin
		if tile in [10, 16]:
			new_tile.rotate_y(-1)
			attach_point2 = new_tile.get_node("AttachPoint").global_transform.origin
			for tile2 in tile_count:
				var new_tile2 = tile_block.instance()
				add_child(new_tile2)
				new_tile2.global_transform.origin = attach_point2
				new_tile2.rotate_y(-1)
				attach_point2 = new_tile2.get_node("AttachPoint").global_transform.origin
		if tile == 32:
			var new_vault = vault.instance()
			add_child(new_vault)
			new_vault.global_transform.origin = attach_point
			new_vault.global_transform.origin.z -= 6
			new_vault.global_transform.origin.y += 2



#func _process(delta):
	#pass
