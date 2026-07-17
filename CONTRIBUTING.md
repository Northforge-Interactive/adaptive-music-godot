# Contributing

Thanks for your interest in Adaptive Music. This is a small, focused addon — the
goal is to keep it that way.

## Ground rules

- **Scope.** The addon does two things: vertical layer blending and bar-quantised
  section transitions. Features outside that (e.g. asset pipelines, DAW
  integration, MIDI) belong in your own project, not here.
- **Godot version.** Target Godot 4.x, GDScript only. No C#/GDExtension.
- **No runtime dependencies.** It must work by dropping `addons/adaptive_music/`
  into a project — nothing to install.

## Development

1. Clone into a test project at `res://addons/adaptive_music/`.
2. Enable **Adaptive Music** in *Project → Project Settings → Plugins*.
3. Make your change; verify with the scripts in `examples/`.

## Style

Code is checked with [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit)
(`gdformat` + `gdlint`). Run before opening a PR:

```bash
pip install "gdtoolkit==4.*"
gdformat .
gdlint .
```

CI runs the same checks on every pull request.

## Pull requests

- One logical change per PR. Keep diffs small.
- Update `README.md` and `CHANGELOG.md` if behaviour or the API changes.
- Describe *why*, not just *what*.

## License

By contributing you agree your contributions are licensed under the MIT License
(see `LICENSE`).
