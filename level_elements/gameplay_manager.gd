extends Node2D
class_name GameplayManager
## Manages a Level, and handles the progression and transition between levels in a LevelPack

signal pack_data_changed
var pack_data: LevelPackData
var pack_state: LevelPackStateData

# Emitted when a new level is entered
signal entered_level
signal started_transition

# if true, level won't have some features available
var is_editing := false

@onready var level: Level = %Level

@onready var transition: Transition = %Transition
var in_transition := false

func _ready() -> void:
	level.gameplay_manager = self
	transition.started_animation.connect(_on_transition_started)
	transition.finished_animation.connect(_on_transition_finished)

func load_level_pack(pack: LevelPackData, state: LevelPackStateData) -> void:
	assert(PerfManager.start("GameplayManager::load_level_pack"))
	pack_data = pack
	pack_state = state
	var level_data := state.get_current_level()
	level.level_data = level_data
	reset()
	pack_data_changed.emit()
	assert(PerfManager.end("GameplayManager::load_level_pack"))

## Sets the current level to the given level id within the pack and loads it.
func set_current_level(id: int) -> void:
	assert(PerfManager.start("GameplayManager::set_current_level (%d)" % id))
	pack_state.current_level = id
	pack_state.save()
	var level_data := pack_state.get_current_level()
	level.level_data = level_data
	reset()
	entered_level.emit()
	assert(PerfManager.end("GameplayManager::set_current_level (%d)" % id))

func has_won_current_level() -> bool:
	return pack_state.current_level in pack_state.completed_levels

func reset() -> void:
	level.exclude_player = is_editing
	level.allow_ui = not is_editing
	level.load_salvaged_doors = not is_editing
	if is_editing:
		transition.cancel()
	level.reset()

func win() -> void:
	if in_transition: return
	level.snd_win.play()
	if not has_won_current_level():
		pack_state.completed_levels[pack_state.current_level] = true
		pack_state.save()
	win_animation("Congratulations!")

func can_exit() -> bool:
	if pack_state.exit_levels.is_empty():
		return false
	var exit: int = pack_state.exit_levels[-1]
	if not pack_data.levels.has(exit):
		pack_state.exit_levels.clear()
		pack_state.exit_positions.clear()
		return false
	return true

func exit_level() -> void:
	if in_transition: return
	if not can_exit():
		return
	transition.world_enter_animation()
	transition.finished_animation.connect(exit_immediately, CONNECT_ONE_SHOT)

## Exits WITHOUT checking
func exit_immediately() -> void:
	var exit_pos: Vector2i = pack_state.exit_positions.pop_back()
	# WAITING4GODOT: pop_back() in packed arrays?
	var exit_lvl: int = pack_state.exit_levels[-1]
	pack_state.exit_levels.remove_at(pack_state.exit_levels.size() - 1)
	set_current_level(exit_lvl)
	level.player.position = exit_pos

## Exits until the i-th entry in the exit stack
func exit_until(i: int) -> void:
	if in_transition: return
	transition.world_enter_animation()
	await transition.finished_animation
	var exit_pos: Vector2i = pack_state.exit_positions[i]
	var exit_lvl: int = pack_state.exit_levels[i]
	pack_state.exit_positions.resize(i)
	pack_state.exit_levels.resize(i)
	set_current_level(exit_lvl)
	level.player.position = exit_pos

func exit_or_reset() -> void:
	if can_exit():
		exit_immediately()
	else:
		reset()

func enter_level(id: int, exit_position: Vector2i) -> void:
	if in_transition: return
	# push onto exit stack
	if pack_data.levels[id].exitable:
		pack_state.exit_levels.push_back(pack_state.current_level)
		pack_state.exit_positions.push_back(exit_position)
	else:
		pack_state.exit_levels.clear()
		pack_state.exit_positions.clear()
	_enter_level(id)

func enter_level_new_stack(id: int) -> void:
	if in_transition: return
	pack_state.exit_levels.clear()
	pack_state.exit_positions.clear()
	_enter_level(id)

func _enter_level(id: int) -> void:
	var _new_level_data: LevelData = pack_data.levels[id]
	var target_level_name := _new_level_data.name
	var target_level_title := _new_level_data.title
	if target_level_name.is_empty():
		target_level_name = "Untitled"
	transition.level_enter_animation(target_level_name, target_level_title)
	await transition.finished_animation
	set_current_level(id)

func win_animation(text: String) -> void:
	if in_transition: return
	transition.win_animation(text)
	transition.finished_animation.connect(exit_or_reset, CONNECT_ONE_SHOT)

func _on_transition_started() -> void:
	level.allow_ui = false
	in_transition = true
	started_transition.emit()

func _on_transition_finished() -> void:
	level.allow_ui = not is_editing
	in_transition = false
