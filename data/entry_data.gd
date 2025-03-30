@tool
extends Resource
class_name EntryData

static var level_element_type := Enums.LevelElementTypes.Entry

@export var position: Vector2i:
	set(val):
		if position == val: return
		position = val
		changed.emit()

const SKIN_AMOUNT = 31
## The id of the level it leads to. -1 means it doesn't lead anywhere
@export var leads_to: int
## The id of the world sprite used. 0 for the default.
@export var skin: int
# TODO: Add entry requirements
## The level IDs that are required to be cleared (goal) for this entry to open.
@export var require: Array[int]

func get_rect() -> Rect2i:
	return Rect2i(position, Vector2i(32, 32))

# TODO: Optimize if needed
func duplicated() -> EntryData:
	return duplicate()

func check_valid(level_data: LevelData, should_correct: bool) -> bool:
	var is_valid := true
	if leads_to == -1:
		level_data.add_invalid_reason("Entry doesn't lead anywhere", true)
		is_valid = is_valid and should_correct
		if should_correct:
			leads_to = 0
	if not skin is int:
		level_data.add_invalid_reason("Entry skin is non-integer", true)
		is_valid = is_valid and should_correct
		if should_correct:
			skin = skin as int
	if skin < 0:
		level_data.add_invalid_reason("Entry skin is less than 0", true)
		is_valid = is_valid and should_correct
		if should_correct:
			skin = 0
	if skin > SKIN_AMOUNT:
		level_data.add_invalid_reason("Entry skin is too large", true)
		is_valid = is_valid and should_correct
		if should_correct:
			skin = SKIN_AMOUNT
		
	return is_valid
