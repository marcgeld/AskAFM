# ``askafm``

`askafm` is a lightweight Unix-style filter for sending text to Apple
Foundation Models and streaming the transformed result back to the terminal.

## Overview

The package centers around ``AskAFM``, an `AsyncParsableCommand` that:

- validates whether the on-device system model is available,
- can list supported FoundationModels languages without creating a session,
- loads and normalizes filter-mode configuration from the user's home directory,
- reads piped standard input when available,
- joins the remaining command line arguments into the user request,
- can parse stdin as a Swift TabularData `DataFrame` when `--tabularData` is
  set,
- optionally applies a requested response language or locale,
- builds a prompt from the user request and input text,
- keeps the built-in runtime tools available for read-only environment context,
- opens a `LanguageModelSession` when the model is ready, and
- streams only the newly generated suffix of each partial response to standard
  output.

In normal filter mode, piped stdin is appended to the user's prompt as input
data. In tabular mode, stdin is not copied into the prompt; it is parsed once
into a DataFrame and exposed through the read-only `tabularData` tool, which
can include statistical insight analysis when requested.
