## Minimal AdaptiveMusicPlayer example.
##
## Drop this on a node in a scene and point the load() paths at your own stems.
## The layers of a section must be one composition split into stems — same tempo,
## length and start phase — so they stay sample-locked.
extends Node

var _music: AdaptiveMusicPlayer


func _ready() -> void:
	_music = AdaptiveMusicPlayer.new()
	add_child(_music)
	_music.bus = &"Music"  # put a limiter on this bus — summed layers can clip
	_music.set_tempo(128.0, 4)

	# Vertical layers: fade in by a single 0..1 intensity value.
	_music.add_section("gameplay")
	_music.add_layer("gameplay", load("res://music/ambient.ogg"), 0.00, 0.12)  # bed
	_music.add_layer("gameplay", load("res://music/bass.ogg"), 0.18, 0.34)
	_music.add_layer("gameplay", load("res://music/drums.ogg"), 0.32, 0.50)
	_music.add_layer("gameplay", load("res://music/lead.ogg"), 0.68, 0.88)

	# A second section with different harmony — transitions are bar-quantised.
	_music.add_section("boss")
	_music.add_layer("boss", load("res://music/boss_base.ogg"), 0.00, 0.20)
	_music.add_layer("boss", load("res://music/boss_lead.ogg"), 0.50, 0.85)

	_music.section_changed.connect(func(name: String): print("now playing: ", name))
	_music.play("gameplay")


func _process(_delta: float) -> void:
	# Drive the vertical blend from whatever represents "tension" in your game.
	var tension := _current_tension()  # 0..1
	_music.set_intensity(tension)


func _current_tension() -> float:
	# Replace with your own signal (enemy count, health, combo, timer…).
	return 0.5


func enter_boss_fight() -> void:
	_music.transition_to("boss")  # crossfades on the next bar line


func warn() -> void:
	_music.play_stinger(load("res://music/warning.ogg"))
