# Filter Mode Architecture

## Default Mode

AskAFM behaves primarily as a Unix-style text filter:

```text
stdin -> FoundationModels -> stdout
```

The default path:

- reads piped stdin when available,
- joins the remaining command line arguments into the user prompt,
- loads filter instructions from `~/.askafm/config.toml`,
- combines stdin with the user request into a model prompt,
- keeps five built-in read-only tools available to the model,
- streams generated output to stdout,
- writes errors to stderr,
- exits non-zero on failure.

## Default Config

AskAFM keeps a small user-editable config file at:

`$HOME/.askafm/config.toml`

Right now the config surface is intentionally small and exposes:

- `filterModeInstructions`, which lets a user customize the default instructions
  used by filter mode,
- `saveSession`, which writes transcript diagnostics to `session.txt` next to
  `config.toml` when enabled,
- `sampling`, which controls the FoundationModels sampling strategy,
- `temperature`, which controls response randomness from `0` through `1`, and
- `maximumResponseTokens`, which caps generated tokens with a positive integer.

During normal startup, AskAFM reads that TOML file into the current in-code
configuration model and then normalizes it back to disk. That means the running
binary becomes the schema authority:

- customized known values are preserved,
- partial config files only need to contain user overrides,
- missing known values can be backfilled from defaults, and
- stale unknown keys are removed.

If the file is missing, unreadable, or invalid TOML, AskAFM writes a fresh
default config before continuing.

`--writedefaultconfig` overwrites that file with the defaults compiled into the
running binary.

## Prompt Shape

When stdin exists, the effective model prompt is:

```text
<user prompt>

Input data:

<stdin content>
```

Without stdin, the user request is sent directly.

`--language` and `--lang` accept BCP 47 language or locale identifiers such as
`sv`, `sv-SE`, and `sv-Latn-SE`. AskAFM validates the locale against the system
model and adds an explicit response-locale instruction to the session.

## Built-In Read-Only Tools

Default mode keeps five low-risk tools available:

- `currentDirectory`
- `currentDateTime`, optionally for an IANA timezone such as `UTC` or `Europe/Stockholm` and a date format such as `yyyy-MM-dd HH:mm`
- `timeZoneInfo`, for listing known IANA timezones and comparing offsets between two timezones
- `insightView`, for read-only statistical and hidden-pattern analysis of CSV, TSV, and JSON tabular text
- `systemInfo`

These tools are intentionally narrow. They only return small pieces of runtime
context for the current process and do not perform side effects. Because they
act as extra input rather than as privileged executors, AskAFM still behaves
primarily as a Unix-style filter.

## What Default Mode Does Not Do

Default mode intentionally does not:

- execute shell commands,
- write files,
- scan the filesystem,
- register side-effecting or action-oriented tools,
- behave like an autonomous coding agent.

This keeps the CLI closer to `grep`, `sed`, `awk`, and `jq` than to an agent
runtime.

## Generated Markdown

Run:

```bash
./generate_docs.sh
```

The script writes generated Markdown output to `docs/askafm.md`.
