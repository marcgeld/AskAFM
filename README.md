# AskAFM

AskAFM is a native Swift command-line tool for interacting with Apple
Foundation Models from the terminal.

It currently supports:

- Unix-style text transformation with `stdin -> model -> stdout`, and
- streaming the response incrementally to standard output.

It also includes built-in read-only tools:

- `currentDirectory`
- `currentDateTime`, optionally for an IANA timezone such as `UTC` or `Europe/Stockholm` and a date format such as `yyyy-MM-dd HH:mm`
- `timeZoneInfo`, for listing known IANA timezones and comparing offsets between two timezones
- `systemInfo`

When `--tabularData` is active, AskAFM also registers:

- `tabularData`, for inspecting loaded tabular stdin and optionally including
  selected statistical insight analyses.

When `--tabularData` is used with piped input, AskAFM parses stdin into a
Swift TabularData `DataFrame` instead of appending the raw input to the prompt.
The model can then inspect the loaded table through `tabularData` and analyze
it by calling `tabularData` with `includeInsights` to list available analyses,
then `analysisSections` to run selected analyses.

## Requirements

- Apple Silicon Mac
- macOS 26 or later
- Xcode 26 / Swift 6.2+
- Apple Intelligence enabled
- Apple Foundation Models available on the machine

The package manifest currently targets `.macOS(.v26)`, so earlier macOS
versions are not supported. The CLI uses Apple Foundation Models on device; it
will not work on Intel Macs or on systems where Apple Intelligence/Foundation
Models are unavailable.

Apple Foundation Models currently have a small context window of 4096 tokens.
AskAFM checks prompt, instruction, and tool token usage before generation when
the SDK exposes token counting, but large files still need to be summarized,
trimmed, or split before sending.

## Build

```bash
swift build
```

## Run

```bash
askafm tell me a joke
```

```bash
askafm where am I
```

```bash
askafm --promptfile prompt.txt
```

```bash
askafm what architecture am I running on
```

If Apple Foundation Models are unavailable, the CLI prints a human-readable
reason to `stderr` and exits with a non-zero status.

## Unix Filter Examples

```bash
cat article.txt | askafm summarize
```

```bash
askafm --inputfile article.txt summarize
```

```bash
askafm --promptfile summarize.txt --inputfile article.txt
```

```bash
cat article.txt | askafm --inputfile - summarize
```

```bash
git diff | askafm generate a commit message
```

```bash
cat logs.txt | askafm find the root cause
```

```bash
cat data.json | askafm convert to YAML
```

```bash
cat data.csv | askafm --tabularData explain the hidden patterns
```

```bash
echo "hello world" | askafm translate to Swedish
```

```bash
askafm --language sv-SE summarize this text in Swedish
```

```bash
askafm --list-supported-languages
```

```bash
askafm what day is it
```

```bash
askafm where am I
```

```bash
askafm what architecture am I running on
```

## Configuration

AskAFM reads its filter configuration from:

`$HOME/.askafm/config.toml`

If the file does not exist, AskAFM creates it automatically at startup with the
current default values. If the file cannot be read or parsed, AskAFM replaces it
with those same defaults.

On ordinary runs, AskAFM treats the in-code Swift configuration model as the
current schema. Existing user values are respected, but the file may be
rewritten so that:

- users only need to include the settings they want to override,
- missing values are filled from the defaults in the running binary, and
- unknown or obsolete keys are removed from the TOML.

You can force the running binary to overwrite that file with its current
standard defaults:

```bash
askafm --writedefaultconfig
```

The config currently exposes filter instructions, session transcript diagnostics,
and FoundationModels generation options. AskAFM also appends a small in-code
note that explains the five built-in read-only tools.

Example:

```toml
saveSession = false
sampling = "automatic"
temperature = 0.0
maximumResponseTokens = 4096

filterModeInstructions = """
Unix text filter. Use only supplied input. Return only the result.
"""
```

`sampling` supports `automatic`, `greedy`, `randomTopK:<k>`, and
`randomProbabilityThreshold:<p>`. `temperature` must be between `0` and `1`,
and `maximumResponseTokens` must be positive.

When `saveSession` is `true`, AskAFM writes the latest FoundationModels session
transcript to `session.txt` in the same directory as `config.toml`.

When stdin is present, AskAFM constructs a model prompt from:

- the user request, and
- the piped input text.

You can also pass an input file with `--inputfile`, or pass `--inputfile -`
to explicitly read from stdin.

The prompt can come from command line arguments or from a text file supplied
with `--promptfile`.

The prompt text comes from all remaining command line arguments, joined with
spaces, so quoting is optional for normal Unix-style usage.

Default mode is intentionally a text-processing pipeline. It does not:

- execute shell commands,
- write files,
- scan the filesystem,
- register side-effecting tools with the model.

The built-in tools are still active in default mode because they are
read-only and only provide small pieces of process context. That keeps AskAFM
in the filter family while still letting it answer questions like "what
directory am I in?", "what time is it?", or "what is the time difference
between UTC and Europe/Stockholm?"
without shelling out.

With `--tabularData`, stdin is treated as structured data rather than plain
prompt text. The loaded `DataFrame` stays inside read-only tools, so the prompt
remains natural while the model can ask for table schema, previews, and
available statistical analyses from `tabularData`, then run only the selected
analysis sections it needs.

## Test

```bash
swift test
```

In sandboxed environments, it can help to redirect SwiftPM caches into the
workspace:

```bash
env CLANG_MODULE_CACHE_PATH=.build/clang-module-cache \
    SWIFTPM_MODULECACHE_OVERRIDE=.build/swiftpm-module-cache \
    swift test --disable-sandbox \
    --cache-path .build/cache \
    --scratch-path .build/scratch
```

## Logging

```bash
log stream --predicate 'subsystem == "com.marcgeld.askafm"'
```

Show debug-level logs while developing:

```bash
log stream --level debug --predicate 'subsystem == "com.marcgeld.askafm"'
```

Filter by category:

```bash
log stream --level debug --predicate 'subsystem == "com.marcgeld.askafm" && category == "CLI"'
```

```bash
log stream --level debug --predicate 'subsystem == "com.marcgeld.askafm" && category == "Configuration"'
```

```bash
log stream --level debug --predicate 'subsystem == "com.marcgeld.askafm" && category == "Model"'
```

```bash
log stream --level debug --predicate 'subsystem == "com.marcgeld.askafm" && category == "TabularData"'
```

```bash
log stream --level debug --predicate 'subsystem == "com.marcgeld.askafm" && category == "Tools"'
```

Tool orchestration logs use `Tools`; logs emitted by a specific tool use
`Tool.<toolName>`.

```bash
log stream --level debug --predicate 'subsystem == "com.marcgeld.askafm" && category == "Tool.currentDateTime"'
```

```bash
log stream --level debug --predicate 'subsystem == "com.marcgeld.askafm" && category == "Tool.tabularData"'
```

```bash
log show --predicate 'subsystem == "com.marcgeld.askafm"' --last 1h
```

## Architecture

AskAFM now separates:

- `filter mode` as the default experience: `stdin -> model -> stdout`
- `future agent mode` as a possible later extension

See [docs/FilterModeArchitecture.md](docs/FilterModeArchitecture.md) for a
short overview.

## Documentation

DocC content lives in:

- `Sources/askafm/askafm.docc/`

Generate Markdown documentation into `./docs/askafm.md` with:

```bash
./generate_docs.sh
```
