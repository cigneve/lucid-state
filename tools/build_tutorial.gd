extends SceneTree
## Generates the tutorial level, levels/level_0.tscn, and quits.
##
## The Terrain layers store their cells as packed binary, which is painful to
## hand-edit, so this script paints from tile coordinates instead. Run with:
##   godot --headless --script res://tools/build_tutorial.gd
##
## Layout, left to right:
##   A  start, shadow zone -> fade to HALF, then grapple the pit via a hook block
##   B  land on the higher ledge, light zone -> back to SOLID
##   C  melee a knockback block to be launched onto the upper platform
##   D  two gates (HALF then SOLID) and the exit

const TILE := 32
const W := 60
const H := 17

# tile -> atlas coords in art/terrain_tiles.tres
const STONE := Vector2i(0, 0)


func _initialize() -> void:
	var root := Node2D.new()
	root.name = "Level"
	root.set_script(load("res://scripts/level.gd"))
	root.set("level_name", "İlk Dokunuş")

	var terrain := Node2D.new()
	terrain.name = "Terrain"
	root.add_child(terrain)

	var tileset: TileSet = load("res://art/terrain_tiles.tres")
	var stone := _make_layer("Stone", terrain, tileset)
	for lname in ["WorldA", "WorldB", "Bars", "Walls", "Bridge", "Door", "TimedA", "TimedB", "Spikes"]:
		_make_layer(lname, terrain, tileset)

	_paint(stone)

	# Zones: shadow to fade to HALF before the pit, light to return to SOLID on the ledge.
	var zones := Node2D.new()
	zones.name = "Zones"
	root.add_child(zones)
	_place(zones, "res://scenes/objects/shadow_zone.tscn", Vector2(7 * TILE, 11 * TILE),
		{"scale": Vector2(5, 4)})
	_place(zones, "res://scenes/objects/light_zone.tscn", Vector2(20 * TILE, 10 * TILE),
		{"scale": Vector2(4, 2)})

	# Objects.
	var objects := Node2D.new()
	objects.name = "Objects"
	root.add_child(objects)
	# Hook block whose centre sits on tile (15, 9), floating over the pit.
	_place(objects, "res://scenes/objects/hook_block.tscn", _center(15, 9), {})
	# Knockback block standing on the ledge (top row 12) at column 28.
	_place(objects, "res://scenes/objects/knockback_block.tscn", Vector2(28 * TILE + TILE / 2, 12 * TILE), {})
	# Gates on the ledge: HALF first, then SOLID.
	_place(objects, "res://scenes/objects/gate.tscn", Vector2(46 * TILE + TILE / 2, 12 * TILE),
		{"lock_form": 1})   # Cfg.Form.HALF
	_place(objects, "res://scenes/objects/gate.tscn", Vector2(52 * TILE + TILE / 2, 12 * TILE),
		{"lock_form": 0})   # Cfg.Form.SOLID
	_place(objects, "res://scenes/objects/exit.tscn", Vector2(56 * TILE + TILE / 2, 12 * TILE), {})

	# NPCs (Turkish, player-facing).
	var npcs := Node2D.new()
	npcs.name = "Npcs"
	root.add_child(npcs)
	_place(npcs, "res://scenes/objects/npc.tscn", Vector2(5 * TILE + TILE / 2, 14 * TILE), {
		"npc_name": "Bekçi",
		"seen_by": 7,
		"lines": PackedStringArray([
			"Hoş geldin. Burada her şey hâline bakar.",
			"Karanlıkta bekle: saydamlaşınca L ile kanca atıp boşluğu aşarsın.",
			"Işık seni geri katılaştırır. Katıyken L bir yumruk; vurduğun bloğa savrulursun.",
			"Kapılardan geçince hâlin oraya mühürlenir. Ölç biç, sonra adım at.",
		]),
	})
	_place(npcs, "res://scenes/objects/npc.tscn", Vector2(25 * TILE + TILE / 2, 12 * TILE), {
		"npc_name": "Fısıltı",
		"seen_by": 7,
		"lines": PackedStringArray([
			"Yükselmek istiyorsan bloğa AŞAĞI doğru vur; ters yöne fırlarsın.",
			"O platforma ancak böyle çıkılır.",
		]),
	})

	# Spawn and ceiling.
	var start := Marker2D.new()
	start.name = "PlayerStart"
	start.position = Vector2(3 * TILE + TILE / 2, 14 * TILE)
	root.add_child(start)

	var ceiling := StaticBody2D.new()
	ceiling.name = "Ceiling"
	ceiling.collision_mask = 0
	var cs := CollisionShape2D.new()
	var wb := WorldBoundaryShape2D.new()
	wb.normal = Vector2(0, 1)
	cs.shape = wb
	ceiling.add_child(cs)
	root.add_child(ceiling)

	_set_owner(root, root)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://levels/level_0.tscn")
	print("saved level_0.tscn err=", err)
	root.free()
	quit()


func _make_layer(lname: String, parent: Node, tileset: TileSet) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = lname
	l.tile_set = tileset
	parent.add_child(l)
	return l


func _paint_tile(layer: TileMapLayer, x: int, y: int) -> void:
	layer.set_cell(Vector2i(x, y), 0, STONE, 0)


func _paint(stone: TileMapLayer) -> void:
	var pit := func(x: int) -> bool: return x >= 12 and x <= 16
	# base floor + ceiling + side walls
	for x in range(W):
		if not pit.call(x):
			_paint_tile(stone, x, 15)
			_paint_tile(stone, x, 16)
		_paint_tile(stone, x, 0)
	for y in range(H):
		_paint_tile(stone, 0, y)
		_paint_tile(stone, W - 1, y)
	# ground surface (row 14), skipping the pit
	for x in range(1, W - 1):
		if not pit.call(x):
			_paint_tile(stone, x, 14)
	# landing ledge (rows 12-14) from just past the pit to the end
	for x in range(17, W - 1):
		_paint_tile(stone, x, 12)
		_paint_tile(stone, x, 13)
		_paint_tile(stone, x, 14)
	# melee platform (rows 9-11) jutting from the ledge
	for x in range(32, 41):
		_paint_tile(stone, x, 9)
		_paint_tile(stone, x, 10)
		_paint_tile(stone, x, 11)


## Centre of tile (tx, ty) for a bottom-centre-origin object.
func _center(tx: int, ty: int) -> Vector2:
	return Vector2(tx * TILE + TILE / 2, ty * TILE + TILE / 2 + TILE / 2)


func _place(parent: Node, path: String, pos: Vector2, props: Dictionary) -> void:
	var n: Node2D = load(path).instantiate()
	n.position = pos
	for k in props:
		n.set(k, props[k])
	parent.add_child(n)


func _set_owner(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_set_owner(c, owner)
