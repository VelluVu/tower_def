class_name RankData
extends Resource

## Ranks: the repeatable gold step after a building's last upgrade (or before a tier its talent node has not opened),
## the gold sink of a player with few towers (decided 2026-11-27, the user: "make some hard caps on stats so it
## doesn't get too crazy"). Every rank adds each step's modify_value once; the rank total of a step never passes its
## cap, and the ranks end when every step is capped. Worth well under a new tower per gold, so building wide stays
## the best use of gold.

## What one rank adds; Multiply damage counts as "more", so the cards' Additive damage never dilutes it.
@export var steps : Array[EvolveResource] = []
## The most the ranks add to each step's stat, in the order of steps.
@export var caps : Array[float] = []
## The first rank's price as a ratio of the building's own Price; every rank after it adds cost_ratio_step.
@export var first_cost_ratio : float = 1.0
@export var cost_ratio_step : float = 0.5


## The price ratio of the rank after ranks_bought ranks.
func get_cost_ratio(ranks_bought : int) -> float:
	return first_cost_ratio + cost_ratio_step * ranks_bought


## What ranks ranks add to step index, capped.
func get_total(index : int, ranks : int) -> float:
	return RankData.capped_total(steps[index].modify_value, ranks, caps[index] if index < caps.size() else INF)


## The ranks it takes to cap every step: past it a rank adds nothing, so none is offered.
func get_max_ranks() -> int:
	var most : int = 0
	for index in steps.size():
		var value : float = absf(steps[index].modify_value)
		if value <= 0.0 or index >= caps.size():
			continue
		most = maxi(most, ceili(caps[index] / value - 0.0001))
	return most


static func capped_total(value : float, ranks : int, cap : float) -> float:
	return minf(value * ranks, cap) if value >= 0.0 else maxf(value * ranks, -cap)
