class_name BuildingUpgradeData
extends Resource

## Gold upgrades of one building type, bought in the selection panel.
## Steps follow the design rhythm: upgrades_per_tier upgrades before each evolve tier.

#every resource is applied once per upgrade step, with its modify_value as is (no roll)
@export var upgrade_resources : Array[EvolveResource] = []
#prices are ratios of the building's own Price (UpgradeRules.gold_price), so one data fits cheap and dear towers
#one ratio per upgrade step, the size is the number of upgrade steps
@export var upgrade_cost_ratios : Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75]
#one ratio per evolve tier
@export var evolve_cost_ratios : Array[float] = [1.5, 2.5, 4.0]
@export var upgrades_per_tier : int = 2
@export var upgrade_icon : Texture2D = null
