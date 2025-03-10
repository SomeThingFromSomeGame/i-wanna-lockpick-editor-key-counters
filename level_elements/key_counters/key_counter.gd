@tool
extends MarginContainer
class_name KeyCounter

static var level_element_type := Enums.LevelElementTypes.KeyCounter

@export var ignore_position := false
@export var data: CounterData:
	set(val):
		if data == val: return
		_disconnect_data()
		data = val
		_connect_data()

const COUNTERPART := preload("res://level_elements/key_counters/counter_part.tscn")
const KEY_START := Vector2i(20, 20)
const KEY_DIFF := Vector2i(204, 68) - KEY_START
const WOOD := preload("res://level_elements/key_counters/box.png")
const STAR := preload("res://level_elements/key_counters/counterstar.png")

@onready var lock_holder := %Holder as Control

var using_i_view_colors := false
var level: Level = null:
	set(val):
		if level == val: return
		disconnect_level()
		level = val

func _ready() -> void:
	assert(PerfManager.start("Counter::_ready"))
	#_create_canvas_items()
	
	if is_instance_valid(level):
		assert(visible)
	update_visuals()
	assert(PerfManager.end("Counter::_ready"))

#func _create_canvas_items() -> void:
	#wood = RenderingServer.canvas_item_create()
	#RenderingServer.canvas_item_set_parent(wood, get_canvas_item())
#	RenderingServer.canvas_item_set_draw_index(door_base, 0)

#func _destroy_canvas_items() -> void:
	#RenderingServer.free_rid(wood)
	
func _enter_tree():
	if not is_node_ready(): return
	
	# reset collisions
	update_visuals()

func _exit_tree():
	# in case that problem ever would appear on doors as well
	custom_minimum_size = Vector2(0, 0)

func _connect_data() -> void:
	if not is_instance_valid(data): return
	data.changed.connect(update_visuals)
	
	if not is_inside_tree(): return
	update_visuals()
	# look.... ok?
	# TODO: maybe not make the door show() itself? this is the only time it happens
	show()

func _disconnect_data() -> void:
	if not is_instance_valid(data): return
	update_visuals()
	data.changed.disconnect(update_visuals)

func disconnect_level() -> void:
	if not is_instance_valid(level): return

func update_visuals() -> void:
	# We will run this later, when we _enter_tree
	if not is_inside_tree(): return
	if not is_instance_valid(data): return
	assert(PerfManager.start(&"Counter::update_visuals"))
	update_position()
	update_textures()
	update_locks()
	#_draw_base()
	#_draw_keys()
	#_draw_counts()
	
	assert(PerfManager.end(&"Counter::update_visuals"))

func update_position() -> void:
	if not ignore_position:
		position = data.position

func update_textures() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(data): return
	custom_minimum_size = Vector2i(data.length, 17 + data.colors.size() * 49)
	
func update_locks() -> void:
	if not is_instance_valid(data): return
	assert(PerfManager.start(&"Counter::update_locks"))
	
	var needed_locks := data.colors.size()
	var current_locks := lock_holder.get_child_count()
	# redo the current ones
	for i in mini(needed_locks, current_locks):
		var lock := lock_holder.get_child(i)
		lock.level = level
		lock.data = data.colors[i]
	# shave off the rest
	if current_locks > needed_locks:
		for _i in current_locks - needed_locks:
			var lock := lock_holder.get_child(-1)
			lock_holder.remove_child(lock)
			NodePool.return_node(lock)
	# or add them
	else:
		for i in range(current_locks, needed_locks):
			var new_lock: CounterPart = NodePool.pool_node(COUNTERPART)
			new_lock.level = level
			new_lock.data = data.colors[i]
			lock_holder.add_child(new_lock)
	
	assert(PerfManager.end(&"Counter::update_locks"))
#var wood: RID

#func _draw_base() -> void:
	#if not is_instance_valid(data): return
	#assert(PerfManager.start("Counter:_draw_base"))
	#RenderingServer.canvas_item_clear(wood)
	##var rect := Rect2(data.position, Vector2i(data.length + 36, 17 + data.colors.size() * 49))
	#
	##RenderingServer.canvas_item_add_nine_patch(wood, rect, Rect2(0,0,63,63), WOOD, Vector2(31, 31), Vector2(31,31), RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH)
	#
	#assert(PerfManager.end("Counter:_draw_base"))
