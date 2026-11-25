class_name Shredder
extends Tower

## The Shredder (2026-11-25, design doc "Second round of towers"): a Nova-like drakeling whose pulse barely hurts but
## tears armour: every enemy a pulse hits gets a ResistanceShred stack (SHRED_PER_STACK off each of its resistances,
## up to MAX_STACKS, for SHRED_SECONDS, refreshed by every pulse). The answer to the armoured and resistant enemies;
## it makes every other tower around it hit harder.

const SHRED_PER_STACK : float = 0.15
const MAX_STACKS : int = 3
const SHRED_SECONDS : float = 4.0
