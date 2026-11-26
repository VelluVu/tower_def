class_name Wall
extends Building


const CONNECTOR_LRDU : String = "CONNECTOR_LRDU"
const CONNECTOR_LRD : String = "CONNECTOR_LRD"
const CONNECTOR_RD : String = "CONNECTOR_RD"
const CONNECTOR_LRU : String = "CONNECTOR_LRU"
const CONNECTOR_LU : String = "CONNECTOR_LU"
const CONNECTOR_LD : String = "CONNECTOR_LD"
const CONNECTOR_LUD : String = "CONNECTOR_LUD"
const CONNECTOR_RUD : String = "CONNECTOR_RUD"
const CONNECTOR_UR : String = "CONNECTOR_UR"
const CONNECTOR_X : String = "CONNECTOR_X"

const HORIZONTAL : String = "HORIZONTAL"
const HORIZONTAL_END_R : String = "HORIZONTAL_END_R"
const HORIZONTAL_END_L : String = "HORIZONTAL_END_L"

const VERTICAL : String = "VERTICAL"
const VERTICAL_END_D : String = "VERTICAL_END_D"
const VERTICAL_END_U : String = "VERTICAL_END_U"

#the wall's look per upgrade stage (palisade, stone, battlements, castle): stage_frames[i] from stage_upgrades[i] upgrades on
@export var stage_frames : Array[SpriteFrames] = []
@export var stage_upgrades : PackedInt32Array = PackedInt32Array([0, 2, 4, 6])

#the element bought for this wall (Physical = Fortress); None for a plain wall. Permanent: sell to change it
const ELEMENT_OVERLAYS : Dictionary[Utils.Element, String] = {
	Utils.Element.Fire: "res://scenes/unit/building/wall_stages/wall_fire_overlay_frames.tres",
	Utils.Element.Frost: "res://scenes/unit/building/wall_stages/wall_frost_overlay_frames.tres",
	Utils.Element.Poison: "res://scenes/unit/building/wall_stages/wall_poison_overlay_frames.tres",
	Utils.Element.Physical: "res://scenes/unit/building/wall_stages/wall_fortress_overlay_frames.tres",
}
#the blocking side: what an enemy hitting the wall gets back (starting numbers, tune with the bot); on the small
#enemy-health scale since 2026-11-26 (1/8 of the old numbers)
const FIRE_BURN_BACK : float = 0.25
const POISON_BACK : float = 0.125
const FROST_FREEZE_SECONDS : float = 0.5
#a share of the attacker's melee hit, which stays on the building scale: 0.5 of it, times 1/8 for enemy health
const THORNS_SHARE : float = 0.0625
#element tiers (bought for every wall of the element): T2 and T3 strengthen both sides
const FIRE_EXPLOSION_DAMAGE : float = 1.0
const FIRE_EXPLOSION_TILES : float = 1.5
const FROST_T3_FREEZE_SECONDS : float = 1.0
const POISON_T2_ATTACK_FACTOR : float = 0.75
const POISON_SPREAD_TILES : float = 1.0
const FORTRESS_T2_DAMAGE_FACTOR : float = 0.8
const FORTRESS_T2_STUN_CHANCE : float = 0.1
const FORTRESS_T2_STUN_SECONDS : float = 1.0
#Fortress T3: enemies prefer a longer detour round it
const FORTRESS_T3_WEIGHT : float = 160.0

var neighbour_buildings : Array[Vector2i]
var upgrade_stage : int = -1
var element : Utils.Element = Utils.Element.None
var element_overlay : AnimatedSprite2D = null


## Gives the wall its element: the overlay, the maze-area effect (LevelGrid, MazeElements) and the blocking side.
func set_element(new_element : Utils.Element) -> void:
	if new_element == element:
		return
	element = new_element
	if ELEMENT_OVERLAYS.has(element):
		element_overlay = AnimatedSprite2D.new()
		element_overlay.sprite_frames = load(ELEMENT_OVERLAYS[element])
		element_overlay.position = animation_control.position
		element_overlay.offset = animation_control.offset
		element_overlay.centered = animation_control.centered
		animation_control.add_sibling(element_overlay)
	_update_sprite()
	#a wall that takes an element late gets the element's bought tiers too
	on_element_tier_changed()
	GameSignals.astar_grid_updated.emit()


## The tier every wall of this element has (BuildingTypeUpgrades): 1, 2 or 3.
func get_element_tier() -> int:
	if element == Utils.Element.None or level == null or level.building_type_upgrades == null:
		return 1
	return level.building_type_upgrades.get_wall_tier(element)


## A tier was bought for this wall's element: Fortress T3 weighs on the paths.
func on_element_tier_changed() -> void:
	if element == Utils.Element.Physical and get_element_tier() >= 3 and is_placed:
		astar_weight = FORTRESS_T3_WEIGHT
		level.grid.set_cell_weight(grid_position, astar_weight)


#Fire T3: the wall goes up in flames when it falls
func destroy_building() -> void:
	if element == Utils.Element.Fire and get_element_tier() >= 3 and level != null:
		var reach : float = FIRE_EXPLOSION_TILES * Utils.TILE_SIZE
		for enemy in level.existing_enemies.duplicate():
			if is_instance_valid(enemy) and not enemy.is_dead and enemy.global_position.distance_to(global_position) <= reach:
				_strike_back(enemy, FIRE_EXPLOSION_DAMAGE, Utils.DamageType.Fire)
	super()


#the blocking side: an enemy that hits an element wall pays for it
func take_damage(damage_data : DamageData) -> void:
	#before the cast: an arrow can land after its archer died
	damage_data.drop_freed_source()
	var attacker : Enemy = damage_data.source as Enemy
	var tier : int = get_element_tier()
	#Poison T2 weakens its attackers, Fortress T2 takes less
	if attacker != null and tier >= 2 and damage_data.damage > 0.0:
		if element == Utils.Element.Poison:
			damage_data.damage *= POISON_T2_ATTACK_FACTOR
		elif element == Utils.Element.Physical:
			damage_data.damage *= FORTRESS_T2_DAMAGE_FACTOR
	var damage : float = damage_data.damage
	super(damage_data)
	if attacker == null or damage <= 0.0 or not is_instance_valid(attacker) or attacker.is_dead:
		return

	match element:
		Utils.Element.Fire:
			_strike_back(attacker, FIRE_BURN_BACK * (2.0 if tier >= 2 else 1.0), Utils.DamageType.Fire)
		Utils.Element.Poison:
			_strike_back(attacker, POISON_BACK * (2.0 if tier >= 2 else 1.0), Utils.DamageType.Poison)
			#T3: the poison spreads to the enemies around the attacker
			if tier >= 3 and level != null:
				for enemy in level.existing_enemies.duplicate():
					if enemy != attacker and is_instance_valid(enemy) and not enemy.is_dead and enemy.global_position.distance_to(attacker.global_position) <= POISON_SPREAD_TILES * Utils.TILE_SIZE:
						_strike_back(enemy, POISON_BACK, Utils.DamageType.Poison)
		Utils.Element.Frost:
			attacker.freeze_for(FROST_T3_FREEZE_SECONDS if tier >= 3 else FROST_FREEZE_SECONDS)
		Utils.Element.Physical:
			var thorns_bonus : float = level.talents.get_total(TalentEffect.Kind.WallThorns) if level != null and level.talents != null else 0.0
			_strike_back(attacker, damage * THORNS_SHARE * (1.0 + thorns_bonus), Utils.DamageType.Physical)
			if tier >= 2 and is_instance_valid(attacker) and randf() < FORTRESS_T2_STUN_CHANCE:
				attacker.freeze_for(FORTRESS_T2_STUN_SECONDS)


func _strike_back(attacker : Enemy, amount : float, damage_type : Utils.DamageType) -> void:
	var hit : DamageData = DamageData.new()
	hit.damage_type = damage_type
	hit.damage = amount
	hit.source = self
	attacker.take_damage(hit)
	hit.free()


## Shows the stage for this many wall upgrades; BuildingTypeUpgrades calls it on every purchase and placement.
func set_upgrade_stage(upgrades : int) -> void:
	var stage : int = 0
	for i in mini(stage_frames.size(), stage_upgrades.size()):
		if upgrades >= stage_upgrades[i]:
			stage = i

	if stage == upgrade_stage or stage >= stage_frames.size():
		return

	upgrade_stage = stage
	animation_control.sprite_frames = stage_frames[stage]
	if is_placed:
		_update_sprite()


func _set_is_placed(value : bool) -> void:
	super(value)
	if value:
		var surrounding_cells : Array[Vector2i] = level.grid.get_surrounding_cells(grid_position)
				
		for cell in surrounding_cells:
			if level.grid.has_building_in_cell_position(cell):
				if level.grid.get_building_from_cell_position(cell) is Trap:
					continue
				neighbour_buildings.append(cell)
		
		_update_sprite()
		
		if not GameSignals.building_destroyed.is_connected(_on_building_removed):
			GameSignals.building_destroyed.connect(_on_building_removed)
		if not GameSignals.sell_building.is_connected(_on_building_removed):
			GameSignals.sell_building.connect(_on_building_removed)
		if not GameSignals.building_placed.is_connected(_on_building_placed):
			GameSignals.building_placed.connect(_on_building_placed)


func _on_building_removed(building : Building) -> void:
	if building is Trap:
		return
		
	if not neighbour_buildings.has(building.grid_position):
		return
		
	neighbour_buildings.erase(building.grid_position)
	_update_sprite()


func _on_building_placed(building : Building) -> void:
	if building is Trap or building == self:
		return

	#only the four neighbour cells shape the sprite
	if not level.grid.get_surrounding_cells(grid_position).has(building.grid_position):
		return

	if neighbour_buildings.has(building.grid_position):
		return
	
	neighbour_buildings.append(building.grid_position)
	_update_sprite()


func _update_sprite() -> void:
	var has_building_left : bool = neighbour_buildings.has(grid_position - Vector2i(1,0))
	var has_building_right : bool = neighbour_buildings.has(grid_position + Vector2i(1,0))
	var has_building_up : bool = neighbour_buildings.has(grid_position - Vector2i(0,1))
	var has_building_down : bool = neighbour_buildings.has(grid_position + Vector2i(0,1))
	var connector : String = connector_animation(has_building_left, has_building_right, has_building_up, has_building_down)
	animation_control.play(connector)
	if element_overlay != null and element_overlay.sprite_frames.has_animation(connector):
		element_overlay.play(connector)


#the wall piece that joins the neighbouring buildings; the line preview uses it for ghost walls too
static func connector_animation(left : bool, right : bool, up : bool, down : bool) -> String:
	if left and right and down and up:
		return CONNECTOR_LRDU
	
	if not left and not right and not up and not down:
		return CONNECTOR_X
	
	if left and right and not down and not up:
		return HORIZONTAL
	
	if up and down and not left and not right:
		return VERTICAL
	
	if left and not right and not up and not down:
		return HORIZONTAL_END_R
	
	if right and not left and not up and not down:
		return HORIZONTAL_END_L
	
	if up and not right and not left and not down:
		return VERTICAL_END_D
	
	if down and not right and not left and not up:
		return VERTICAL_END_U
	
	if left and right and up and not down:
		return CONNECTOR_LRU
	
	if left and right and down and not up:
		return CONNECTOR_LRD
	
	if left and up and down and not right:
		return CONNECTOR_LUD
	
	if right and up and down and not left:
		return CONNECTOR_RUD
	
	if left and up and not right and not down:
		return CONNECTOR_LU
	
	if left and down and not right and not up:
		return CONNECTOR_LD
	
	if right and down and not left and not up:
		return CONNECTOR_RD
	
	if right and up and not left and not down:
		return CONNECTOR_UR

	return CONNECTOR_X
