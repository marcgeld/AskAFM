//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import ArgumentParser
import Darwin
import Foundation
import FoundationModels
import core

/// Dump the session transcript to a string for debugging purposes. Each entry is separated and labeled by its index in the transcript.
extension LanguageModelSession {
    func transcriptDump() -> String {
        let entries = transcript.enumerated().map { index, entry in
            var dumpOutput = ""
            dump(entry, to: &dumpOutput)
            return "Entry \(index)\n\(dumpOutput)"
        }
        return "Transcript entries: \(transcript.count)\n"
            + entries.joined(separator: "\n")
            + "\n"
    }
}

/// A simple extension to write strings directly to a FileHandle, such as standard output or standard error, by encoding the string as UTF-8 data.
extension FileHandle {
    func write(_ string: String) {
        write(Data(string.utf8))
    }
}

/// A command-line entry point for streaming responses from Apple Foundation Models.
@main
struct AskAFM: AsyncParsableCommand {
    private static let logger = AskAFMLogger.cli
    private static let modelLogger = AskAFMLogger.model
    private static let tabularLogger = AskAFMLogger.tabularData

    static let configuration = CommandConfiguration(
        commandName: "askafm",
        abstract: "Ask Apple Foundation Models a question"
    )

    /// The user prompt passed from the CLI.
    @Argument(
        parsing: .remaining,
        help: "Prompt text to send to AskAFM."
    )
    var promptParts: [String] = []

    /// Optional file path containing the prompt text.
    @Option(
        name: [.long, .customLong("promptfile")],
        help: "Text file containing the prompt."
    )
    var promptFile: String?

    /// Optional input file path, or `-` to force reading standard input.
    @Option(
        name: [.long, .customLong("inputfile")],
        help: "Input file or '-' for stdin."
    )
    var inputFile: String?

    /// Optional BCP 47 language or locale identifier to prefer for the model response, such as `sv`, `sv-SE`, or `sv-Latn-SE`.
    @Option(
        name: [.long, .customLong("lang")],
        help: "Set the response language/locale, for example sv, sv-SE, or sv-Latn-SE."
    )
    var language: String?

    /// A flag to list the languages supported by the on-device language model and exit without creating a session.
    @Flag(
        name: .shortAndLong,
        help:
            "List the languages supported by the on-device language model and exit without creating a session."
    )
    var listSupportedLanguages = false

    /// A flag to write the default configuration to disk and exit, useful for users to get started with a template config file.
    @Flag(
        name: .long,
        help: "Write the current default configuration to ~/.askafm/config.toml and exit."
    )
    var writedefaultconfig = false

    /// A flag to signal that input is Tabular data, which the model process as TabularData instead of plain text.
    @Flag(
        name: .shortAndLong,
        help: """
            Indicates that the input data is Tabular data, which will be processed as a structured table instead of plain text.
            The model will attempt to parse the input into rows and columns.
            """
    )
    var tabularData = false

    struct ContextUsage: Equatable {
        let promptTokens: Int
        let instructionTokens: Int
        let toolTokens: Int
        let contextSize: Int

        var totalTokens: Int {
            promptTokens + instructionTokens + toolTokens
        }

        var remainingTokens: Int {
            contextSize - totalTokens
        }

        var exceedsContextSize: Bool {
            totalTokens > contextSize
        }
    }

    /// Returns a human-readable explanation when the system language model cannot be used.
    ///
    /// - Parameter availability: The current availability state reported by
    ///   `SystemLanguageModel`.
    /// - Returns: A localized-style message describing why the model is unavailable,
    ///   or `nil` when the model can be used.
    static func unavailableReason(
        for availability: SystemLanguageModel.Availability
    ) -> String? {
        switch availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "Device does not support Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is toggled off in device Settings"
        case .unavailable(.modelNotReady):
            return "Model is still downloading or preparing"
        case .unavailable(let reason):
            return "Unexpected Apple Intelligence unavailability: \(reason)"
        }
    }

    /// Computes the portion of a streamed response that has not yet been printed.
    ///
    /// The method compares the UTF-8 prefixes instead of character counts so the CLI
    /// can append incremental output with less overhead while still handling complete
    /// response resets safely.
    ///
    /// - Parameters:
    ///   - current: The latest accumulated response text from the model stream.
    ///   - previous: The previously rendered response text.
    /// - Returns: The new suffix to write to standard output. If the stream no longer
    ///   shares the same prefix, the full `current` value is returned.
    static func incrementalSuffix(
        current: String,
        previous: String
    ) -> String {
        guard current.utf8.starts(with: previous.utf8) else {
            return current
        }

        let suffixStart = current.utf8.index(
            current.utf8.startIndex,
            offsetBy: previous.utf8.count
        )
        return String(decoding: current.utf8[suffixStart...], as: UTF8.self)
    }

    /// Checks whether the standard input is a TTY (interactive terminal) or not, which can be used to determine if there is piped input to read.
    static func isStandardInputTTY(
        stdinFileDescriptor: Int32 = STDIN_FILENO
    ) -> Bool {
        isatty(stdinFileDescriptor) != 0
    }

    /// Determines whether the CLI should attempt to read from standard input based on whether it is a TTY or not.
    static func shouldReadFromStdin(isStandardInputTTY: Bool) -> Bool {
        !isStandardInputTTY
    }

    /// Reads the entire content from standard input if it is not a TTY, returning `nil` otherwise.
    static func standardInputContentIfAvailable(
        standardInputIsTTY: Bool,
        standardInput: FileHandle = .standardInput
    ) throws -> String? {
        guard shouldReadFromStdin(isStandardInputTTY: standardInputIsTTY)
        else {
            return nil
        }

        let data = try standardInput.readToEnd() ?? Data()
        logger.debug("Read \(data.count) bytes from stdin")
        return String(decoding: data, as: UTF8.self)
    }

    /// Reads explicit input from a file, or from standard input when `-` is supplied.
    static func readInput(
        inputFile: String?,
        standardInput: FileHandle = .standardInput,
        fileReader: (String) throws -> String = {
            try String(contentsOfFile: $0, encoding: .utf8)
        }
    ) throws -> String? {
        guard let inputFile else {
            return nil
        }

        if inputFile == "-" {
            let data = try standardInput.readToEnd() ?? Data()
            logger.debug("Read \(data.count) bytes from explicit stdin")
            return String(decoding: data, as: UTF8.self)
        }

        let content = try fileReader(inputFile)
        logger.debug("Read \(content.utf8.count) bytes from input file")
        return content
    }

    /// Reads explicit prompt text from a file.
    static func readPrompt(
        promptFile: String?,
        fileReader: (String) throws -> String = {
            try String(contentsOfFile: $0, encoding: .utf8)
        }
    ) throws -> String? {
        guard let promptFile else {
            return nil
        }

        let prompt = try fileReader(promptFile)
        logger.debug("Read \(prompt.utf8.count) bytes from prompt file")
        return prompt
    }

    /// Parses piped stdin into the canonical tabular dataset when tabular mode
    /// is active. In normal filter mode, stdin remains plain prompt input.
    static func tabularDataset(
        enabled: Bool,
        stdinContent: String?
    ) throws -> InsightDataset? {
        guard enabled else {
            tabularLogger.debug("Tabular input mode disabled")
            return nil
        }

        guard let stdinContent else {
            tabularLogger.error("Tabular input mode enabled without stdin")
            throw InsightView.InsightViewError.emptyInput
        }

        tabularLogger.info("Parsing stdin as tabular data")
        let dataset = try InsightDataset.parse(stdinContent)
        tabularLogger.info(
            "Parsed tabular stdin as \(dataset.inputFormat) with \(dataset.rowCount) rows and \(dataset.columns.count) columns"
        )
        return dataset
    }

    /// Combines the user prompt and optional standard input content into a single prompt string to send to the model.
    static func modelPrompt(
        userRequest: String,
        stdinContent: String?
    ) -> String {
        guard let stdinContent else {
            logger.debug("Building model prompt without stdin content")
            return userRequest
        }

        logger.debug(
            "Building model prompt with \(stdinContent.utf8.count) stdin bytes"
        )
        return """
            \(userRequest)

            Input:
            \(stdinContent)
            """
    }

    /// Builds the prompt for the selected input mode.
    static func modelPrompt(
        userRequest: String,
        stdinContent: String?,
        tabularData: Bool
    ) -> String {
        logger.debug("Building model prompt. tabularData=\(tabularData)")
        return tabularData
            ? userRequest
            : modelPrompt(userRequest: userRequest, stdinContent: stdinContent)
    }

    /// Joins the array of prompt parts into a single string.
    static func userPrompt(from promptParts: [String]) -> String {
        promptParts.joined(separator: " ")
    }

    /// Returns the effective prompt from an optional prompt file or positional
    /// prompt arguments.
    static func userPrompt(
        promptFileContent: String?,
        promptParts: [String]
    ) -> String {
        promptFileContent ?? userPrompt(from: promptParts)
    }

    /// Combines the filter mode instructions from the configuration with the built-in tool instructions
    /// to create the full session instructions for the model.
    static func sessionInstructions(
        configuration: AskAFMConfiguration,
        languageIdentifier: String? = nil,
        tabularDataset: InsightDataset? = nil
    ) -> String {
        logger.debug(
            "Building session instructions. language=\(languageIdentifier ?? "none"), tabularDatasetLoaded=\(tabularDataset != nil)"
        )
        return [
            configuration.filterModeInstructions,
            languageInstructions(languageIdentifier: languageIdentifier),
            builtinToolInstructions(tabularDataset: tabularDataset),
        ]
        .compactMap(trimmedNonEmpty)
        .joined(separator: "\n")
    }

    private static func builtinToolInstructions(
        tabularDataset: InsightDataset? = nil
    ) -> String {
        [
            "Tools are read-only. Prefer supplied input; call tools only for runtime context.",
            tabularDataInstructions(tabularDataset: tabularDataset),
        ]
        .compactMap(trimmedNonEmpty)
        .joined(separator: "\n")
    }

    private static func tabularDataInstructions(
        tabularDataset: InsightDataset?
    ) -> String {
        guard let tabularDataset else {
            return ""
        }

        return """
            Tabular input loaded: \(tabularDataset.rowCount) rows, \(tabularDataset.columns.count) cols. Raw input omitted; use tabularData includeInsights to list analyses, then analysisSections to run selected analyses.
            """
    }

    /// Builds the optional language instruction used when `--language`/`--lang` is supplied.
    static func languageInstructions(languageIdentifier: String?) -> String {
        guard let languageIdentifier = trimmedNonEmpty(languageIdentifier) else {
            return ""
        }

        let language = Locale.Language(identifier: languageIdentifier)
        return """
            Reply locale: \(language.maximalIdentifier). Preserve source text unless translation is requested.
            """
    }

    /// Converts a user-provided BCP 47 language identifier to a Foundation locale.
    static func modelLocale(languageIdentifier: String?) -> Locale? {
        guard let languageIdentifier = trimmedNonEmpty(languageIdentifier) else {
            return nil
        }

        return Locale(identifier: languageIdentifier)
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    /// Formats supported model languages as newline-separated BCP 47 identifiers.
    static func supportedLanguagesOutput(
        languages: Set<Locale.Language>
    ) -> String {
        let text =
            languages
            .map(\.maximalIdentifier)
            .sorted()
            .joined(separator: "\n")

        return text.isEmpty ? "" : text + "\n"
    }

    static func contextWindowMessage(usage: ContextUsage) -> String {
        "Context window exceeded: \(usage.totalTokens)/\(usage.contextSize) tokens (prompt \(usage.promptTokens), instructions \(usage.instructionTokens), tools \(usage.toolTokens))."
    }

    @available(iOS 26.4, macOS 26.4, visionOS 26.4, *)
    static func contextUsage(
        model: SystemLanguageModel,
        prompt: String,
        instructions: Instructions,
        tools: [any Tool]
    ) async throws -> ContextUsage {
        async let promptTokens = model.tokenCount(for: prompt)
        async let instructionTokens = model.tokenCount(for: instructions)
        async let toolTokens = model.tokenCount(for: tools)

        return try await ContextUsage(
            promptTokens: promptTokens,
            instructionTokens: instructionTokens,
            toolTokens: toolTokens,
            contextSize: model.contextSize
        )
    }

    /// Converts AskAFM's persisted model settings into FoundationModels generation options.
    static func generationOptions(
        configuration: AskAFMConfiguration
    ) -> GenerationOptions {
        modelLogger.debug(
            "Building generation options. sampling=\(configuration.sampling.tomlValue), temperature=\(configuration.temperature), maximumResponseTokens=\(configuration.maximumResponseTokens)"
        )
        return GenerationOptions(
            sampling: samplingMode(for: configuration.sampling),
            temperature: configuration.temperature,
            maximumResponseTokens: configuration.maximumResponseTokens
        )
    }

    private static func samplingMode(
        for sampling: AskAFMSamplingStrategy
    ) -> GenerationOptions.SamplingMode? {
        switch sampling {
        case .automatic:
            return nil
        case .greedy:
            return .greedy
        case .randomTopK(let topK):
            return .random(top: topK)
        case .randomProbabilityThreshold(let threshold):
            return .random(probabilityThreshold: threshold)
        }
    }

    /// Returns an array of the built-in tools available to the model.
    static func builtinTools(
        tabularData: Bool = false,
        tabularDataset: InsightDataset? = nil
    ) -> [any Tool] {
        var tools: [any Tool] = [
            CurrentDirectoryTool(),
            TimeDateTool(),
            TimeZoneTool(),
        ]

        if tabularData {
            if let tabularDataset {
                tools.append(TabularDataTool(dataset: tabularDataset))
            }
        }

        tools.append(SystemInfoTool())
        logger.debug(
            "Registered built-in tools: \(tools.map(\.name).joined(separator: ", "))"
        )
        return tools
    }

    /// Writes an error message to the specified standard error handle, appending a newline.
    static func writeError(
        _ message: String,
        to standardError: FileHandle = .standardError
    ) {
        standardError.write(Data((message + "\n").utf8))
    }

    /// Validates the command-line arguments and configuration before attempting to create a model session.
    mutating func validate() throws {
        let exitsWithoutPrompt = writedefaultconfig || listSupportedLanguages
        guard promptFile == nil || promptParts.isEmpty else {
            Self.logger.error("Validation failed: both promptfile and prompt arguments provided")
            throw ValidationError(
                "Use either --promptfile or prompt arguments, not both."
            )
        }

        guard exitsWithoutPrompt || promptFile != nil || !Self.userPrompt(from: promptParts).isEmpty else {
            Self.logger.error("Validation failed: missing prompt")
            throw ValidationError(
                "Missing prompt or --promptfile unless --writedefaultconfig or --list-supported-languages is used."
            )
        }
        let promptPartCount = promptParts.count
        let shouldListSupportedLanguages = listSupportedLanguages
        let shouldWriteDefaultConfig = writedefaultconfig
        let usesTabularData = tabularData
        let hasInputFile = inputFile != nil
        let hasPromptFile = promptFile != nil
        Self.logger.debug(
            "Validated arguments. promptParts=\(promptPartCount), promptFile=\(hasPromptFile), inputFile=\(hasInputFile), listSupportedLanguages=\(shouldListSupportedLanguages), writeDefaultConfig=\(shouldWriteDefaultConfig), tabularData=\(usesTabularData)"
        )
    }

    /// Starts a model session, streams the answer, and writes incremental updates to
    /// standard output.
    ///
    /// If the on-device language model is unavailable, the command prints a friendly
    /// explanation instead of attempting to create a session.
    mutating func run() async throws {
        Self.logger.info("AskAFM run started")
        let stdout = FileHandle.standardOutput
        let stderr = FileHandle.standardError
        let model = SystemLanguageModel.default

        if listSupportedLanguages {
            Self.logger.info("Listing supported model languages")
            stdout.write(
                Self.supportedLanguagesOutput(
                    languages: model.supportedLanguages
                )
            )
            return
        }

        if writedefaultconfig {
            Self.logger.info("Writing default configuration and exiting")
            let url = try AskAFMConfigurationStore().writeDefault()
            stdout.write("Wrote default config to \(url.path)\n")
            return
        }

        if let locale = Self.modelLocale(languageIdentifier: language),
            !model.supportsLocale(locale)
        {
            let identifier = Locale.Language(identifier: language ?? "")
                .maximalIdentifier
            Self.writeError(
                "Unsupported language or locale: \(identifier)",
                to: stderr
            )
            Self.logger.error("Unsupported language or locale: \(identifier)")
            throw ExitCode.failure
        }

        let availability = model.availability
        Self.modelLogger.debug("System language model availability: \(String(describing: availability))")
        if let unavailabilityMessage = Self.unavailableReason(
            for: availability
        ) {
            Self.logger.error("System language model unavailable: \(unavailabilityMessage)")
            Self.writeError(unavailabilityMessage, to: stderr)
            throw ExitCode.failure
        }

        let promptFileContent = try Self.readPrompt(
            promptFile: promptFile
        )
        let inputContent = try Self.readInput(
            inputFile: inputFile
        )
        let stdinContent: String?
        if let inputContent {
            stdinContent = inputContent
        } else {
            stdinContent = try Self.standardInputContentIfAvailable(
                standardInputIsTTY: Self.isStandardInputTTY()
            )
        }
        let configurationStore = AskAFMConfigurationStore()
        let configuration = try configurationStore.loadOrCreate()
        Self.logger.debug(
            "Starting filter mode. stdin bytes present: \(stdinContent?.utf8.count ?? 0)"
        )

        let tabularDataset: InsightDataset?
        do {
            tabularDataset = try Self.tabularDataset(
                enabled: tabularData,
                stdinContent: stdinContent
            )
        } catch {
            Self.writeError(
                "Could not parse tabular stdin: \(error.localizedDescription)",
                to: stderr
            )
            Self.tabularLogger.error(
                "Could not parse tabular stdin: \(String(describing: error))"
            )
            throw ExitCode.failure
        }
        let prompt = Self.modelPrompt(
            userRequest: Self.userPrompt(
                promptFileContent: promptFileContent,
                promptParts: promptParts
            ),
            stdinContent: stdinContent,
            tabularData: tabularData
        )
        Self.logger.debug("Model prompt length: \(prompt.utf8.count) bytes")
        let instructions = Self.sessionInstructions(
            configuration: configuration,
            languageIdentifier: language,
            tabularDataset: tabularDataset
        )
        Self.logger.debug("Session instructions length: \(instructions.utf8.count) bytes")
        let instructionObject = Instructions(instructions)
        let tools = Self.builtinTools(
            tabularData: tabularData,
            tabularDataset: tabularDataset
        )

        if #available(macOS 26.4, *) {
            let usage = try await Self.contextUsage(
                model: model,
                prompt: prompt,
                instructions: instructionObject,
                tools: tools
            )
            Self.modelLogger.info(
                "Context usage: total=\(usage.totalTokens), prompt=\(usage.promptTokens), instructions=\(usage.instructionTokens), tools=\(usage.toolTokens), limit=\(usage.contextSize), remaining=\(usage.remainingTokens)"
            )
            if usage.exceedsContextSize {
                let message = Self.contextWindowMessage(usage: usage)
                Self.writeError(message, to: stderr)
                Self.modelLogger.error("\(message)")
                throw ExitCode.failure
            }
        }

        let session = LanguageModelSession(
            model: model,
            tools: tools,
            instructions: instructionObject
        )
        Self.modelLogger.info("Starting model response stream")
        let stream = session.streamResponse(
            to: prompt,
            options: Self.generationOptions(configuration: configuration)
        )

        var renderedContent = ""
        for try await partialText in stream {
            let currentContent = partialText.content
            let suffix = Self.incrementalSuffix(
                current: currentContent,
                previous: renderedContent
            )

            guard !suffix.isEmpty else {
                continue
            }

            stdout.write(suffix)
            renderedContent = currentContent
            Self.modelLogger.debug(
                "Stream rendered \(renderedContent.utf8.count) bytes so far"
            )
        }
        Self.modelLogger.info("Model response stream completed with \(renderedContent.utf8.count) output bytes")

        if configuration.saveSession {
            let sessionURL = try configurationStore.writeSession(
                session.transcriptDump()
            )
            Self.logger.info("Wrote session transcript to \(sessionURL.path)")
        } else {
            Self.logger.debug("Session transcript saving disabled")
        }
        stdout.write("\n")
        Self.logger.info("AskAFM run completed successfully")
    }
}
