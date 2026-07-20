@icon("res://addons/adaptive_music/icon.svg")
class_name AdaptiveMusicPlayer
extends Node
## Adaptive music player: vertical layer blending + horizontal section transitions.
##
## Two mechanisms, both tempo-locked:
##   • LAYERS   — stems that play together (phase-locked) and fade in/out by a single
##                0..1 `intensity`. Use for a continuous energy morph (calm↔intense)
##                with NO transition. Layers in a section MUST share tempo, length and
##                phase (render them as one piece split into stems).
##   • SECTIONS — mutually-exclusive layer groups. `transition_to()` crossfades to
##                another section, quantised to the next bar/beat, so a section with
##                different harmony (e.g. a boss theme) switches cleanly without a
##                tempo clash. Sections should share tempo so the crossfade beat-matches.
##
## A plain crossfade does NOT tempo-match; it just overlaps two players. This class
## keeps everything at one tempo and quantises switches so overlaps stay musical.
##
## Usage:
##   var m := AdaptiveMusicPlayer.new()
##   add_child(m)
##   m.bus = &"Music"
##   m.set_tempo(128.0, 4)
##   m.add_section("gameplay")
##   m.add_layer("gameplay", load("res://.../ambient.ogg"), 0.00, 0.12)
##   m.add_layer("gameplay", load("res://.../bass.ogg"),    0.18, 0.34)
##   ...
##   m.add_section("boss")
##   m.add_layer("boss", load("res://.../boss_base.ogg"), 0.0, 0.2)
##   m.play("gameplay")
##   m.set_intensity(0.7)          # blend layers
##   m.transition_to("boss")       # bar-quantised crossfade
##   m.play_stinger(load("res://.../warn.ogg"))

signal beat(index: int)  ## emitted on each beat of the active section
signal bar(index: int)  ## emitted on each bar
signal section_changed(name: String)  ## emitted when a (quantised) transition completes

## Volume (dB) treated as silence; layers below their fade-in sit here.
const SILENCE_DB := -60.0

## Audio bus for every layer. Put a limiter on it — summed layers can exceed 0 dBFS.
@export var bus: StringName = &"Master"
## Seconds a layer takes to ease toward its intensity-driven target volume.
@export var layer_smooth: float = 0.25
## Crossfade length (seconds) for section transitions.
@export var transition_time: float = 1.0

var _tempo := 120.0
var _beats_per_bar := 4
var _sections: Dictionary = {}  ## name -> Array[Dictionary] (layer defs)
var _active := ""
var _intensity := 0.0
var _playing := false

# clock (seconds since the active section started playing)
var _clock := 0.0
var _last_beat := -1
var _last_bar := -1

# pending quantised transition
var _pending := ""
var _pending_at := -1.0  ## clock time to execute the swap (<0 = none)


func set_tempo(bpm: float, beats_per_bar: int = 4) -> void:
	_tempo = maxf(1.0, bpm)
	_beats_per_bar = maxi(1, beats_per_bar)


func add_section(name: String) -> void:
	if not _sections.has(name):
		_sections[name] = []


## Register a layer in a section. `fade_in_at`/`full_at` are intensity thresholds
## (0..1): below fade_in_at the layer is silent, at/above full_at it's at `max_db`,
## linear-eased between. `max_db` is the layer's level when fully in.
func add_layer(
	section: String, stream: AudioStream, fade_in_at: float, full_at: float, max_db: float = 0.0
) -> void:
	add_section(section)
	if stream is AudioStreamOggVorbis or stream is AudioStreamWAV:
		stream.loop = true if stream is AudioStreamOggVorbis else stream.loop
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = SILENCE_DB
	add_child(p)
	var layer := {
		"player": p,
		"a": minf(fade_in_at, full_at),
		"b": maxf(full_at, fade_in_at + 0.001),
		"max_db": max_db,
		"cur_db": SILENCE_DB,
		"tween": null,   # active fade/stop tween, if any — killed before a new one
	}
	var layers: Array = _sections[section]
	layers.append(layer)


## Kill a layer's pending fade/stop tween so it can't fire (e.g. a late stop() that
## would silence a freshly (re)started player). Safe to call when none is pending.
func _kill_layer_tween(layer: Dictionary) -> void:
	var tw = layer.get("tween")
	if tw != null and is_instance_valid(tw) and (tw as Tween).is_valid():
		(tw as Tween).kill()
	layer["tween"] = null


## Fade a layer to a target dB, optionally stopping it at the end. Cancels any
## pending tween on that layer first so overlapping fades can't fight or the old
## one's stop-callback can't fire after a restart.
func _fade_layer(layer: Dictionary, to_db: float, dur: float, stop_after: bool) -> void:
	_kill_layer_tween(layer)
	var p: AudioStreamPlayer = layer["player"]
	var tw := create_tween()
	layer["tween"] = tw
	tw.tween_property(p, "volume_db", to_db, dur)
	if stop_after:
		tw.tween_callback(p.stop)


## Start a section immediately (all its layers begin phase-locked). Resets the clock.
func play(section: String) -> void:
	if not _sections.has(section):
		push_warning("AdaptiveMusicPlayer: unknown section '%s'" % section)
		return
	# Cancel every pending fade/stop tween across all sections first. Without this, a
	# stop() fade still in flight (e.g. from a run ending) fires its p.stop() callback
	# seconds into the new section and silences the just-started music.
	for s in _sections:
		for layer in _sections[s]:
			_kill_layer_tween(layer)
	for other in _sections:
		if other != section:
			_silence_section(other, true)
	_active = section
	_clock = 0.0
	_last_beat = -1
	_last_bar = -1
	_pending = ""
	_pending_at = -1.0
	_playing = true
	for layer in _sections[section]:
		var p: AudioStreamPlayer = layer["player"]
		layer["cur_db"] = SILENCE_DB
		p.volume_db = SILENCE_DB
		p.play()
	_apply_intensity(true)


## Drive the vertical blend. Clamped 0..1. Eased over `layer_smooth`.
func set_intensity(x: float) -> void:
	_intensity = clampf(x, 0.0, 1.0)


## Crossfade to another section. quantize: "bar" (default), "beat" or "now".
func transition_to(section: String, quantize: String = "bar") -> void:
	if not _sections.has(section) or section == _active:
		return
	if not _playing:
		play(section)
		return
	if quantize == "now":
		_do_transition(section)
		return
	_pending = section
	_pending_at = _clock + (_time_to_next_beat() if quantize == "beat" else _time_to_next_bar())


## Fire a one-shot (non-looping) cue over the current mix; frees itself.
func play_stinger(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = false
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func stop(fade: float = 1.0) -> void:
	_playing = false
	for section in _sections:
		_silence_section(section, fade <= 0.0, fade)


func shutdown() -> void:
	_playing = false
	_pending = ""
	_pending_at = -1.0
	for section in _sections:
		for layer: Dictionary in _sections[section]:
			_kill_layer_tween(layer)
			var player := layer["player"] as AudioStreamPlayer
			player.stop()
			player.stream = null
	_sections.clear()


func _exit_tree() -> void:
	shutdown()


func active_section() -> String:
	return _active


## Pause/resume every layer (keeps phase). Use for game pause.
func set_paused(paused: bool) -> void:
	for section in _sections:
		for layer in _sections[section]:
			(layer["player"] as AudioStreamPlayer).stream_paused = paused


func beat_position() -> float:
	return _clock * _tempo / 60.0


func bar_position() -> float:
	return beat_position() / float(_beats_per_bar)


# ── internals ────────────────────────────────────────────────────────────────


func _process(delta: float) -> void:
	if _playing:
		_clock += delta
		_emit_clock_signals()
		if _pending_at >= 0.0 and _clock >= _pending_at:
			_do_transition(_pending)
	_apply_intensity(false, delta)


func _emit_clock_signals() -> void:
	var b := int(floor(beat_position()))
	if b != _last_beat:
		_last_beat = b
		beat.emit(b)
	var br := int(floor(bar_position()))
	if br != _last_bar:
		_last_bar = br
		bar.emit(br)


func _time_to_next_bar() -> float:
	var spb := 60.0 / _tempo * float(_beats_per_bar)
	return spb - fmod(_clock, spb)


func _time_to_next_beat() -> float:
	var sb := 60.0 / _tempo
	return sb - fmod(_clock, sb)


func _do_transition(section: String) -> void:
	# Start the incoming section phase-locked, crossfade the outgoing out.
	var outgoing := _active
	_active = section
	_pending = ""
	_pending_at = -1.0
	for layer in _sections[section]:
		_kill_layer_tween(layer)      # incoming is driven by _apply_intensity, no stale fade
		var p: AudioStreamPlayer = layer["player"]
		layer["cur_db"] = SILENCE_DB
		p.volume_db = SILENCE_DB
		if not p.playing:
			p.play()
	if outgoing != "" and _sections.has(outgoing):
		for layer in _sections[outgoing]:
			_fade_layer(layer, SILENCE_DB, transition_time, true)
	section_changed.emit(section)


func _apply_intensity(instant: bool, delta: float = 0.0) -> void:
	if _active == "" or not _sections.has(_active):
		return
	var k := 1.0 if instant else clampf(delta / maxf(layer_smooth, 0.001), 0.0, 1.0)
	for layer in _sections[_active]:
		var t := clampf((_intensity - layer["a"]) / (layer["b"] - layer["a"]), 0.0, 1.0)
		t = smoothstep(0.0, 1.0, t)
		var target: float = SILENCE_DB if t <= 0.001 else lerpf(SILENCE_DB, layer["max_db"], t)
		layer["cur_db"] = target if instant else lerpf(layer["cur_db"], target, k)
		var p: AudioStreamPlayer = layer["player"]
		p.volume_db = layer["cur_db"]


func _silence_section(section: String, immediate: bool, fade: float = 1.0) -> void:
	if not _sections.has(section):
		return
	for layer in _sections[section]:
		var p: AudioStreamPlayer = layer["player"]
		if immediate:
			_kill_layer_tween(layer)
			p.stop()
			p.volume_db = SILENCE_DB
			layer["cur_db"] = SILENCE_DB
		elif p.playing:
			_fade_layer(layer, SILENCE_DB, fade, true)
