extends Resource
class_name LevelData

@export var doors: Array[DoorData] = []

@export var keys: Array[KeyData] = []

@export var keycounters: Array[CounterData] = []

@export var entries: Array[EntryData] = []

@export var salvage_points: Array[SalvagePointData] = []

## This array refers to other levels in the level pack, that are required for this level to be unlocked.
@export var required_levels := PackedInt32Array()

## How many levels from required_levels need to be completed for this level to be unlocked.
@export var min_required_level_count := 0

## Whether you can exit this level.
@export var exitable := true

const SMALLEST_SIZE := Vector2i(800, 608)
signal changed_size
@export var size := SMALLEST_SIZE:
	set(val):
		if size == val: return
		size = val
		changed_size.emit()

signal changed_player_spawn_position
@export var player_spawn_position := Vector2i(398, 304):
	set(val):
		if player_spawn_position == val: return
		player_spawn_position = val
		changed_player_spawn_position.emit()

signal changed_goal_position
@export var goal_position := Vector2i(0, 0):
	set(val):
		if goal_position == val: return
		goal_position = val
		changed_goal_position.emit()

var has_goal := true:
	set(val):
		if not val:
			goal_position = Vector2i(-32, -32)
	get:
		return goal_position.x >= 0

## Just saves all positions for the tiles... I'll come up with something better later ok
@export var tiles := {}

## Name of the level, used when standing in front of an entry that leads to it
@export var name := "":
	set(val):
		if name == val: return
		name = val
		changed.emit()

## Title of the level, for example "Level 4-1" or "Page 3"
@export var title := "":
	set(val):
		if title == val: return
		title = val
		changed.emit()

## Short (if you want) label for the level, used for the warp rod. [br]
## If it's empty, it won't be included in the warp rod
@export var label := "":
	set(val):
		if label == val: return
		label = val
		changed.emit()

@export var author := "":
	set(val):
		if author == val: return
		author = val
		changed.emit()

@export var description := "":
	set(val):
		if author == val: return
		author = val
		changed.emit()

## Used to determine how many entries need to be cleared in a world for it to be cleared.
## Will not be a world if set to 0.
@export var world_clear := 0:
	set(val):
		if world_clear == val: return
		world_clear = val
		changed.emit()

func _init() -> void:
	changed_player_spawn_position.connect(emit_changed)
	changed_goal_position.connect(emit_changed)

func duplicated() -> LevelData:
	var dupe := LevelData.new()
	dupe.size = size
	dupe.player_spawn_position = player_spawn_position
	dupe.goal_position = goal_position
	dupe.tiles = tiles.duplicate(true)
	dupe.name = name
	dupe.title = title
	dupe.world_clear = world_clear
	for door in doors:
		dupe.doors.push_back(door.duplicated())
	for key in keys:
		dupe.keys.push_back(key.duplicated())
	for counter in keycounters:
		dupe.keycounters.push_back(counter.duplicated())
	for entry in entries:
		dupe.entries.push_back(entry.duplicated())
	for salvage_point in salvage_points:
		dupe.salvage_points.push_back(salvage_point.duplicated())
	return dupe

static func get_default_level() -> LevelData:
	var level: LevelData = load("res://editor/levels/default_level.tres").duplicated()
	level.resource_path = ""
	return level

func get_container_for_elem_type(type: Enums.LevelElementTypes):
	match type:
		Enums.LevelElementTypes.Door: return doors
		Enums.LevelElementTypes.Key: return keys
		Enums.LevelElementTypes.KeyCounter: return keycounters
		Enums.LevelElementTypes.SalvagePoint: return salvage_points
		Enums.LevelElementTypes.Entry: return entries
		Enums.LevelElementTypes.Tile: return tiles
		_: return null

## Builds up a collision system based on the data.
func get_collision_system() -> CollisionSystem:
	var collision_system := CollisionSystem.new(16)
	assert(PerfManager.start("LevelData::get_collision_system"))
	collision_system.add_rect(Rect2i(player_spawn_position - Vector2i(14, 32), Vector2i(32, 32)), Enums.LevelElementTypes.PlayerSpawn)
	if has_goal:
		collision_system.add_rect(Rect2i(goal_position, Vector2i(32, 32)), Enums.LevelElementTypes.Goal)
	for door in doors:
		collision_system.add_rect(door.get_rect(), door)
	for key in keys:
		collision_system.add_rect(key.get_rect(), key)
	for counter in keycounters:
		collision_system.add_rect(counter.get_rect(), counter)
	for entry in entries:
		collision_system.add_rect(entry.get_rect(), entry)
	for salvage_point in salvage_points:
		collision_system.add_rect(salvage_point.get_rect(), salvage_point)
	for tile_coord in tiles.keys():
		# Bad idea to store just a Vector2i without identifying it as a tile, perhaps?
		collision_system.add_rect(Rect2i(tile_coord * 32, Vector2i(32, 32)), tile_coord)
	assert(PerfManager.end("LevelData::get_collision_system"))
	return collision_system

static func get_element_type(elem: Variant) -> Enums.LevelElementTypes:
	if elem is Enums.LevelElementTypes:
		return elem
	if elem is Vector2i:
		return Enums.LevelElementTypes.Tile
	return elem.level_element_type

static func get_element_grid_size(type: Enums.LevelElementTypes) -> Vector2i:
	if type == Enums.LevelElementTypes.Tile:
		return Vector2i(32, 32)
	elif type == Enums.LevelElementTypes.KeyCounter:
		return Vector2i(2, 2)
	else:
		return Vector2i(16, 16)

## Deletes stuff outside the level boundary
func clear_outside_things() -> void:
	var amount_deleted := 0
	# tiles
	var deleted_ones := []

	for key in tiles.keys():
		var pos = key * Vector2i(32, 32)
		if pos.x < 0 or pos.y < 0 or pos.x + 32 > size.x or pos.y + 32 > size.y:
			deleted_ones.push_back(key)
	for pos in deleted_ones:
		var worked := tiles.erase(pos)
		assert(worked == true)
	
	amount_deleted += deleted_ones.size()

	# doors
	deleted_ones.clear()
	for door in doors:
		var max = door.position + door.size
		if door.position.x < 0 or door.position.y < 0 or max.x > size.x or max.y > size.y:
			deleted_ones.push_back(door)
	for door in deleted_ones:
		doors.erase(door)
	amount_deleted += deleted_ones.size()
	# keys
	deleted_ones.clear()
	for key in keys:
		var max = key.position + Vector2i(32, 32)
		if key.position.x < 0 or key.position.y < 0 or max.x > size.x or max.y > size.y:
			deleted_ones.push_back(key)
	for key in deleted_ones:
		keys.erase(key)
	amount_deleted += deleted_ones.size()
	if amount_deleted != 0:
		print("deleted %d outside things" % amount_deleted)

# Only the keys are used. values are true for fixable and false for unfixable
var _fixable_invalid_reasons := {}
var _unfixable_invalid_reasons := {}
func add_invalid_reason(reason: StringName, fixable: bool) -> void:
	if fixable:
		_fixable_invalid_reasons[reason] = fixable
	else:
		_unfixable_invalid_reasons[reason] = fixable

func get_fixable_invalid_reasons() -> Array:
	return _fixable_invalid_reasons.keys()

func get_unfixable_invalid_reasons() -> Array:
	return _unfixable_invalid_reasons.keys()

# Checks if the level is valid.
# if should_correct is true, corrects whatever invalid things it can.
func check_valid(should_correct: bool) -> void:
	_fixable_invalid_reasons.clear()
	_unfixable_invalid_reasons.clear()
	clear_outside_things()
	
	# TODO: Check collisions between things
	# etc...
	
	if size.x < SMALLEST_SIZE.x or size.y < SMALLEST_SIZE.y:
		add_invalid_reason(&"Level size is too small.", true)
		if should_correct:
			size.x = maxi(SMALLEST_SIZE.x, size.x)
			size.y = maxi(SMALLEST_SIZE.y, size.y)
	if size != size.snapped(Vector2i(32, 32)):
		add_invalid_reason(&"Level size isn't a multiple of 32x32.", true)
		if should_correct:
			size = size.snapped(Vector2i(32, 32))
	
	# Make sure player spawn is aligned to the grid + inside the level
	const PLAYER_SPAWN_OFFSET := Vector2i(14, 32)
	var new_pos := player_spawn_position
	# offset so it's presumably inside the grid
	new_pos -= PLAYER_SPAWN_OFFSET
	# clamp to grid and level size
	new_pos = new_pos.snapped(Vector2i(16, 16))
	new_pos = new_pos.clamp(Vector2i.ZERO, size - Vector2i(32, 32))
	# put it back
	new_pos += PLAYER_SPAWN_OFFSET
	# if the position was initially correct, it shouldn't have changed
	if player_spawn_position != new_pos:
		print("Oh noo invalid!")
		add_invalid_reason("Invalid player position.", true)
		if should_correct:
			player_spawn_position = new_pos
	for door in doors:
		door.check_valid(self, should_correct)
	for salvage_point in salvage_points:
		salvage_point.check_valid(self, should_correct)

func get_screenshot() -> Image:
	var viewport := SubViewport.new()
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var vpc := SubViewportContainer.new()
	# TODO: No.
	vpc.position = Vector2(INF, INF)
	viewport.size = size
	vpc.size = viewport.size
	vpc.add_child(viewport)
	if not Engine.get_main_loop().root.is_node_ready():
		await Engine.get_main_loop().root.ready
	Engine.get_main_loop().root.add_child(vpc)
	
	var lvl: Level = preload("res://level_elements/level.tscn").instantiate()
	lvl.exclude_player = true
	lvl.level_data = duplicated()
	viewport.add_child(lvl)
	
	await RenderingServer.frame_post_draw 
	var img := viewport.get_texture().get_image()
	vpc.free()
	return img
