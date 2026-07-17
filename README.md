# Adaptive Music (Godot 4)

Tempo-locked adaptive music. Two mechanisms, both beat-matched:

- **Layers (vertical)** — stems that play phase-locked and fade in/out by a single
  `intensity` (0..1). A seamless energy morph — calm → intense — with *no*
  transition. Layers of a section must share tempo, length and phase (render them
  as one piece, split into stems).
- **Sections (horizontal)** — mutually-exclusive layer groups. `transition_to()`
  crossfades to another section **quantised to the next bar**, so a section with
  different harmony (e.g. a boss theme) switches without a tempo clash.

Why quantise? A plain crossfade doesn't tempo-match — it just overlaps two
players, and if their tempos or bar phases differ you get a clash. Keeping one
tempo and switching on the bar line makes overlaps musical.

## Install

The repo *is* the addon — its root maps to `res://addons/adaptive_music/`.

**Copy:** download and drop the files into `addons/adaptive_music/` in your
project.

**Submodule:**

```bash
git submodule add https://github.com/Northforge-Interactive/adaptive-music-godot.git addons/adaptive_music
```

Then enable **Adaptive Music** in *Project → Project Settings → Plugins*.
`AdaptiveMusicPlayer` is then a global class you can `new()` or add as a node.

Requires **Godot 4.x**. Put a **limiter** on the target bus — summed layers can
exceed 0 dBFS.

## Quick start

```gdscript
var m := AdaptiveMusicPlayer.new()
add_child(m)
m.bus = &"Music"
m.set_tempo(128.0, 4)

m.add_section("gameplay")
m.add_layer("gameplay", load("res://music/ambient.ogg"), 0.00, 0.12)  # always-on bed
m.add_layer("gameplay", load("res://music/bass.ogg"),    0.18, 0.34)
m.add_layer("gameplay", load("res://music/drums.ogg"),   0.32, 0.50)
m.add_layer("gameplay", load("res://music/arp.ogg"),     0.50, 0.70)
m.add_layer("gameplay", load("res://music/lead.ogg"),    0.68, 0.88)

m.add_section("boss")
m.add_layer("boss", load("res://music/boss_base.ogg"), 0.00, 0.20)
m.add_layer("boss", load("res://music/boss_lead.ogg"), 0.50, 0.85)

m.play("gameplay")
m.set_intensity(0.7)          # blend the gameplay layers (call every frame/tick)
m.transition_to("boss")       # bar-quantised crossfade into the boss section
m.play_stinger(load("res://music/warning.ogg"))
m.transition_to("gameplay")   # back
```

## API

| Member | Purpose |
|---|---|
| `bus: StringName` | output bus for all layers (default `Master`) |
| `set_tempo(bpm, beats_per_bar=4)` | tempo for the beat clock + quantisation |
| `add_section(name)` | create a section |
| `add_layer(section, stream, fade_in_at, full_at, max_db=0)` | add a layer; intensity thresholds 0..1 |
| `play(section)` | start a section (layers begin phase-locked) |
| `set_intensity(x)` | 0..1 vertical blend, eased over `layer_smooth` |
| `transition_to(section, quantize="bar")` | crossfade; `"bar"`/`"beat"`/`"now"` |
| `play_stinger(stream, volume_db=0)` | one-shot cue, frees itself |
| `stop(fade=1.0)` | fade everything out |
| signals | `beat(index)`, `bar(index)`, `section_changed(name)` |

## Preparing stems

The layers of a section must be one composition split into parts, all the **same
tempo, length and start phase** so they stay sample-locked. A click-free loop
trick: render each layer for three loops and keep the middle one, crossfaded into
the third at the seam, so the loop point has no discontinuity. Sections can be
different pieces but should share a tempo so `transition_to()` beat-matches.

## License

MIT — see `LICENSE`.

---

Built for and battle-tested in [PULSE//ZERO](https://northforge-interactive.itch.io/pulse-zero)
by [Northforge Interactive](https://github.com/Northforge-Interactive).
