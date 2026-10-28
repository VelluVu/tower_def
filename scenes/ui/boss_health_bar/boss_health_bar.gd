class_name BossHealthBar
extends Control

## The top-centre bar of a living boss (Enemy.is_boss): its name and health, hidden otherwise.

@onready var name_label : Label = $MarginContainer/PanelContainer/VBoxContainer/NameLabel
@onready var health_bar : ProgressBar = $MarginContainer/PanelContainer/VBoxContainer/HealthBar

var boss : Enemy = null


func _ready() -> void:
	hide()
	GameSignals.enemy_spawned.connect(_on_enemy_spawned)
	GameSignals.enemy_destroyed.connect(_on_enemy_gone)
	GameSignals.enemy_reached_end_point.connect(_on_enemy_gone)


#health also drops from burns and poison ticks, so it is read every frame while shown
func _process(_delta : float) -> void:
	if not is_instance_valid(boss):
		_clear()
		return

	health_bar.max_value = boss.stats.get_stat_value(Utils.StatType.MaxHealth)
	health_bar.value = boss.stats.get_stat_value(Utils.StatType.Health)


func _on_enemy_spawned(enemy : Enemy) -> void:
	if not enemy.is_boss:
		return

	boss = enemy
	name_label.text = enemy.selectable.display_name if enemy.selectable.display_name != "" else enemy.name
	show()
	set_process(true)


func _on_enemy_gone(enemy : Enemy) -> void:
	if enemy == boss:
		_clear()


func _clear() -> void:
	boss = null
	hide()
	set_process(false)
