# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-17

Initial public release. Extracted from the game **PULSE//ZERO**, where it drives
the adaptive gameplay soundtrack.

### Added

- `AdaptiveMusicPlayer` — tempo-locked adaptive music node for Godot 4.
- Vertical layer blending: stems fade in/out by a single `intensity` (0..1),
  phase-locked with no transition.
- Horizontal section transitions: `transition_to()` crossfades to another
  section quantised to the next bar/beat.
- One-shot stingers via `play_stinger()`.
- `beat`, `bar` and `section_changed` signals.

[0.1.0]: https://github.com/Northforge-Interactive/adaptive-music-godot/releases/tag/v0.1.0
