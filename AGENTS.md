# AGENTS

## Purpose

This repository contains a Swift Package Manager CLI for Apple Foundation
Models. Keep changes small, buildable, and easy to verify from the terminal.

## Architecture

- `Sources/askafm/` contains the executable target.
- `Sources/core/` contains shared support code, currently logging.
- `Sources/askafm/tools/` contains model-callable tools used by
  `LanguageModelSession`.
- `Tests/askafmTests/` contains unit tests for CLI helpers and tool behavior.

## Working Agreements

- Prefer small, composable helper methods over large `run()` bodies.
- Keep streaming output logic allocation-light and deterministic where possible.
- When adding a Foundation Models tool, conform to `FoundationModels.Tool`
  directly rather than introducing a parallel abstraction with the same name.
- Sort filesystem-derived output before asserting on it in tests.
- Skip hidden files unless there is a deliberate product reason not to.

## Verification

Run this before wrapping up substantial changes:

```bash
env CLANG_MODULE_CACHE_PATH=.build/clang-module-cache \
    SWIFTPM_MODULECACHE_OVERRIDE=.build/swiftpm-module-cache \
    swift test --disable-sandbox \
    --cache-path .build/cache \
    --scratch-path .build/scratch
```

## Documentation

- Keep `README.md` aligned with real build and run commands.
- Add or update DocC comments when touching public-facing behavior or important
  CLI flows.
