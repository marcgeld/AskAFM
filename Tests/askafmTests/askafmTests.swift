//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import FoundationModels
import Testing

@testable import askafm

@Test func unavailableReasonReturnsNilWhenModelIsAvailable() async throws {
    #expect(
        AskAFM.unavailableReason(for: .available) == nil
    )
}

@Test func unavailableReasonExplainsKnownCases() async throws {
    #expect(
        AskAFM.unavailableReason(
            for: .unavailable(.deviceNotEligible)
        ) == "Device does not support Apple Intelligence"
    )
    #expect(
        AskAFM.unavailableReason(
            for: .unavailable(.appleIntelligenceNotEnabled)
        ) == "Apple Intelligence is toggled off in device Settings"
    )
    #expect(
        AskAFM.unavailableReason(
            for: .unavailable(.modelNotReady)
        ) == "Model is still downloading or preparing"
    )
}

@Test func validateRequiresQuestionUnlessUsingPromptlessUtilityFlag() async throws {
    await #expect(throws: (any Error).self) {
        _ = try await AskAFM.parseAsRoot([])
    }

    _ = try await AskAFM.parseAsRoot(["--writedefaultconfig"])
    let listCommand = try await AskAFM.parseAsRoot([
        "--list-supported-languages",
    ]) as? AskAFM

    _ = try await AskAFM.parseAsRoot(["tell", "me", "a", "joke"])
    _ = try await AskAFM.parseAsRoot(["--promptfile", "prompt.txt"])

    #expect(listCommand?.listSupportedLanguages == true)
}

@Test func promptOnlyInvocationKeepsFirstWordAsPromptText() async throws {
    let command = try await AskAFM.parseAsRoot([
        "tell",
        "me",
        "a",
        "joke",
    ]) as? AskAFM

    #expect(command?.inputFile == nil)
    #expect(command?.promptParts == ["tell", "me", "a", "joke"])
    #expect(AskAFM.userPrompt(from: command?.promptParts ?? []) == "tell me a joke")
}

@Test func inputFileOptionAcceptsExplicitInputFile() async throws {
    let command = try await AskAFM.parseAsRoot([
        "--inputfile",
        "notes.txt",
        "summarize",
    ]) as? AskAFM

    #expect(command?.inputFile == "notes.txt")
    #expect(command?.promptParts == ["summarize"])
}

@Test func promptFileOptionAcceptsExplicitPromptFile() async throws {
    let command = try await AskAFM.parseAsRoot([
        "--promptfile",
        "prompt.txt",
    ]) as? AskAFM

    #expect(command?.promptFile == "prompt.txt")
    #expect(command?.promptParts == [])
}

@Test func promptFileCannotBeCombinedWithPromptArguments() async throws {
    await #expect(throws: (any Error).self) {
        _ = try await AskAFM.parseAsRoot([
            "--promptfile",
            "prompt.txt",
            "summarize",
        ])
    }
}

@Test func languageOptionAcceptsLongNameAndAlias() async throws {
    let longCommand = try await AskAFM.parseAsRoot([
        "--language",
        "sv-SE",
        "sammanfatta",
    ]) as? AskAFM
    let aliasCommand = try await AskAFM.parseAsRoot([
        "--lang",
        "sv-Latn-SE",
        "sammanfatta",
    ]) as? AskAFM

    #expect(longCommand?.language == "sv-SE")
    #expect(aliasCommand?.language == "sv-Latn-SE")
}

@Test func languageOptionAddsLocaleInstruction() async throws {
    let instructions = AskAFM.sessionInstructions(
        configuration: .default,
        languageIdentifier: "sv-SE"
    )

    #expect(instructions.contains("Reply locale: sv-Latn-SE."))
}

@Test func supportedLanguagesOutputListsOneLanguagePerLine() async throws {
    let output = AskAFM.supportedLanguagesOutput(
        languages: [
            Locale.Language(identifier: "sv-SE"),
            Locale.Language(identifier: "en-US"),
        ]
    )

    #expect(output == "en-Latn-US\nsv-Latn-SE\n")
}

@Test func contextUsageComputesTotalsAndRemainingTokens() async throws {
    let usage = AskAFM.ContextUsage(
        promptTokens: 100,
        instructionTokens: 20,
        toolTokens: 30,
<<<<<<< HEAD
        contextSize: 256
=======
        contextSize: 256,
        exact: true
>>>>>>> 355dfdb (Handle os versions)
    )

    #expect(usage.totalTokens == 150)
    #expect(usage.remainingTokens == 106)
    #expect(usage.exceedsContextSize == false)
}

@Test func contextUsageDetectsExceededContextWindow() async throws {
    let usage = AskAFM.ContextUsage(
        promptTokens: 240,
        instructionTokens: 20,
        toolTokens: 10,
<<<<<<< HEAD
        contextSize: 256
=======
        contextSize: 256,
        exact: true
>>>>>>> 355dfdb (Handle os versions)
    )

    #expect(usage.totalTokens == 270)
    #expect(usage.remainingTokens == -14)
    #expect(usage.exceedsContextSize)
}

@Test func contextWindowMessageSummarizesTokenSources() async throws {
    let usage = AskAFM.ContextUsage(
        promptTokens: 240,
        instructionTokens: 20,
        toolTokens: 10,
<<<<<<< HEAD
        contextSize: 256
=======
        contextSize: 256,
        exact: true
>>>>>>> 355dfdb (Handle os versions)
    )

    let message = AskAFM.contextWindowMessage(usage: usage)

    #expect(message.contains("270/256 tokens"))
    #expect(message.contains("prompt 240"))
    #expect(message.contains("instructions 20"))
    #expect(message.contains("tools 10"))
}

<<<<<<< HEAD
=======
@Test func fallbackContextUsageEstimatesTokensWithoutExactSDKSupport() async throws {
    let usage = AskAFM.fallbackContextUsage(
        prompt: "abcd efgh",
        instructions: "short",
        tools: [],
        contextSize: 4096
    )

    #expect(usage.contextSize == 4096)
    #expect(usage.exact == false)
    #expect(usage.promptTokens > 0)
    #expect(usage.instructionTokens > 0)
    #expect(usage.toolTokens == 0)
}

>>>>>>> 355dfdb (Handle os versions)
@Test func builtinToolsReturnsIntegratedReadOnlyTools() async throws {
    let tools = AskAFM.builtinTools()
    let toolNames = tools.map(\.name)

    #expect(toolNames.count == 4)
    #expect(
        toolNames == [
            "currentDirectory",
            "currentDateTime",
            "timeZoneInfo",
            "systemInfo",
        ]
    )
}

@Test func builtinToolsExposeTabularDataToolWhenDatasetIsLoaded() async throws {
    let dataset = try InsightDataset.parse(
        """
        value,label
        1,alpha
        2,beta
        """
    )
    let tools = AskAFM.builtinTools(
        tabularData: true,
        tabularDataset: dataset
    )
    let toolNames = tools.map(\.name)

    #expect(toolNames.count == 5)
    #expect(toolNames.contains("tabularData"))
    #expect(!toolNames.contains("insightView"))
}

@Test func timeDateToolUsesRequestedTimezone() async throws {
    let tool = TimeDateTool()
    let output = try await tool.run(
        now: Date(timeIntervalSince1970: 0),
        timezone: "UTC"
    )

    #expect(output.contains("Current date:"))
    #expect(output.contains("Current time:"))
    #expect(output.contains("Timezone: UTC"))
}

@Test func timeDateToolUsesRequestedFormatAndTimezone() async throws {
    let tool = TimeDateTool()
    let output = try await tool.run(
        now: Date(timeIntervalSince1970: 0),
        timezone: "UTC",
        format: "yyyy-MM-dd HH:mm"
    )

    #expect(output.contains("Formatted date/time: 1970-01-01 00:00"))
    #expect(output.contains("Format: yyyy-MM-dd HH:mm"))
    #expect(output.contains("Timezone: UTC"))
}

@Test func timeDateToolRejectsInvalidTimezone() async throws {
    let tool = TimeDateTool()

    await #expect(throws: TimeDateTool.TimeDateToolError.self) {
        _ = try await tool.run(timezone: "Not/AZone")
    }
}

@Test func timeZoneToolListsKnownTimezones() async throws {
    let tool = TimeZoneTool()
    let output = try await tool.run(listAll: true)

    #expect(output.contains("Known timezones"))
    #expect(output.contains("UTC"))
    #expect(output.contains("Europe/Stockholm"))
}

@Test func timeZoneToolComparesTimezoneOffsets() async throws {
    let tool = TimeZoneTool()
    let output = try await tool.run(
        fromTimezone: "UTC",
        toTimezone: "Europe/Stockholm",
        now: Date(timeIntervalSince1970: 0)
    )

    #expect(output.contains("From timezone: UTC"))
    #expect(output.contains("To timezone: Europe/Stockholm"))
    #expect(output.contains("Offset difference: +01:00"))
    #expect(output.contains("Europe/Stockholm is 1 hour ahead of UTC."))
}

@Test func timeZoneToolRequiresTimezonePairForComparison() async throws {
    let tool = TimeZoneTool()

    await #expect(throws: TimeZoneTool.TimeZoneToolError.self) {
        _ = try await tool.run(fromTimezone: "UTC")
    }
}

@Test func creditsToolReturnsExpectedSections() async throws {
    let tool = CreditsTool()
    let output = try await tool.run()

    #expect(output.contains("AskAFM"))
    #expect(output.contains("Author"))
    #expect(output.contains("License"))
    #expect(output.contains("Homepage"))
}

@Test func insightViewAnalyzesCSVInputAcrossAllSections() async throws {
    let insightView = InsightView()
    let report = try insightView.run(
        inputText: """
            value,category,related
            1,a,2
            2,a,4
            3,b,6
            4,b,8
            100,c,200
            """
    )

    #expect(report.inputFormat == "csv")
    #expect(report.rowCount == 5)
    #expect(report.columnCount == 3)
    #expect(report.dataQuality.qualityScore > 0)
    #expect(report.summaryStatistics.contains { $0.column == "value" })
    #expect(report.distributionCharacteristics.contains { $0.column == "value" })
    #expect(report.benfordAnalysis.contains { $0.column == "value" })
    #expect(report.zipfAnalysis.contains { $0.column == "category" })
    #expect(report.paretoAnalysis.contains { $0.column == "value" })
    #expect(report.normalityAnalysis.contains { $0.column == "value" })
    #expect(report.uniformityAnalysis.contains { $0.column == "value" })
    #expect(report.outlierAnalysis.contains { $0.column == "value" })
    #expect(
        report.relationshipAnalysis.pearsonCorrelationMatrix["value"]?["related"] == 1
    )
    #expect(report.insightSummary.conciseExplanation.isEmpty == false)
}

@Test func insightViewParsesJSONTabularInput() async throws {
    let insightView = InsightView()
    let report = try insightView.run(
        inputText: """
            [
              {"amount": 10, "label": "alpha"},
              {"amount": 20, "label": "beta"},
              {"amount": 40, "label": "beta"}
            ]
            """
    )

    #expect(report.inputFormat == "json")
    #expect(report.rowCount == 3)
    #expect(report.summaryStatistics.contains { $0.column == "amount" })
    #expect(report.dataQuality.detectedColumnTypes["amount"] == "numeric")
}

@Test func insightViewAnalyzesLoadedTabularDataset() async throws {
    let dataset = try InsightDataset.parse(
        """
        amount,label
        10,alpha
        20,beta
        40,beta
        """
    )
    let insightView = InsightView(loadedDataset: dataset)
    let report = try insightView.run()

    #expect(report.rowCount == 3)
    #expect(report.columnCount == 2)
    #expect(report.summaryStatistics.contains { $0.column == "amount" })
}

@Test func tabularDataToolShowsLoadedDataFrameAndPreview() async throws {
    let dataset = try InsightDataset.parse(
        """
        amount,label
        10,alpha
        20,beta
        """
    )
    let tool = TabularDataTool(dataset: dataset)
    let output = try await tool.run(includeRows: true, rowLimit: 1)

    #expect(output.contains("Tabular dataset"))
    #expect(output.contains("Rows: 2"))
    #expect(output.contains("Columns: 2"))
    #expect(output.contains("amount"))
    #expect(output.contains("1. amount=10, label=alpha"))
}

@Test func tabularDataToolCanIncludeInsightAnalysis() async throws {
    let dataset = try InsightDataset.parse(
        """
        amount,label
        10,alpha
        20,beta
        40,beta
        """
    )
    let tool = TabularDataTool(dataset: dataset)
    let output = try await tool.run(includeInsights: true)

    #expect(output.contains("Available analyses:"))
    #expect(output.contains("quality"))
    #expect(output.contains("summary"))
    #expect(!output.contains(#""rowCount" : 3"#))
}

@Test func tabularDataToolRunsSelectedInsightAnalysis() async throws {
    let dataset = try InsightDataset.parse(
        """
        amount,label
        10,alpha
        20,beta
        40,beta
        """
    )
    let tool = TabularDataTool(dataset: dataset)
    let output = try await tool.run(analysisSections: "quality,summary")

    #expect(output.contains("Insights:"))
    #expect(output.contains("quality:"))
    #expect(output.contains("summary:"))
    #expect(output.contains(#""qualityScore""#))
    #expect(output.contains(#""column" : "amount""#))
}

@Test(
    arguments: [
        ("quality", #""qualityScore""#),
        ("summary", #""column" : "amount""#),
        ("distributions", #""skewness""#),
        ("benford", #""observedFrequencies""#),
        ("zipf", #""fittedExponent""#),
        ("pareto", #""concentrationAssessment""#),
        ("normality", #""confidenceAssessment""#),
        ("uniformity", #""confidenceAssessment""#),
        ("outliers", #""outlierCount""#),
        ("relationships", #""pearsonCorrelationMatrix""#),
        ("summaryText", #""conciseExplanation""#),
    ]
)
func tabularDataToolRunsEachAnalysisSection(
    section: String,
    expectedOutput: String
) async throws {
    let dataset = try InsightDataset.parse(
        """
        amount,label,related
        10,alpha,20
        20,beta,40
        40,beta,80
        100,gamma,200
        """
    )
    let tool = TabularDataTool(dataset: dataset)
    let output = try await tool.run(analysisSections: section)

    #expect(output.contains("Insights:"))
    #expect(output.contains("\(section.lowercased()):"))
    #expect(output.contains(expectedOutput))
}

@Test func tabularDataToolEncodesNonFiniteInsightValues() async throws {
    let dataset = try InsightDataset.parse(
        """
        amount,label
        10,alpha
        10,beta
        10,gamma
        """
    )
    let tool = TabularDataTool(dataset: dataset)
    let output = try await tool.run(analysisSections: "summary")

    #expect(output.contains("Insights:"))
    #expect(!output.contains("TabularDataTool(logger:"))
}

@Test func incrementalSuffixReturnsOnlyNewContent() async throws {
    let suffix = AskAFM.incrementalSuffix(
        current: "Hello, world!",
        previous: "Hello"
    )

    #expect(suffix == ", world!")
}

@Test func incrementalSuffixHandlesNoChange() async throws {
    let suffix = AskAFM.incrementalSuffix(
        current: "Hej",
        previous: "Hej"
    )

    #expect(suffix.isEmpty)
}

@Test func incrementalSuffixFallsBackWhenStreamResets() async throws {
    let suffix = AskAFM.incrementalSuffix(
        current: "Rewritten answer",
        previous: "Original answer"
    )

    #expect(suffix == "Rewritten answer")
}

@Test func shouldReadFromStdinOnlyWhenInputIsNotTTY() async throws {
    #expect(AskAFM.shouldReadFromStdin(isStandardInputTTY: true) == false)
    #expect(AskAFM.shouldReadFromStdin(isStandardInputTTY: false) == true)
}

@Test func standardInputContentIfAvailableReturnsNilForTTY() async throws {
    let pipe = Pipe()
    pipe.fileHandleForWriting.write(Data("ignored".utf8))
    pipe.fileHandleForWriting.closeFile()

    let content = try AskAFM.standardInputContentIfAvailable(
        standardInputIsTTY: true,
        standardInput: pipe.fileHandleForReading
    )

    #expect(content == nil)
}

@Test func standardInputContentIfAvailableReadsPipedInput() async throws {
    let pipe = Pipe()
    pipe.fileHandleForWriting.write(Data("hello\nworld".utf8))
    pipe.fileHandleForWriting.closeFile()

    let content = try AskAFM.standardInputContentIfAvailable(
        standardInputIsTTY: false,
        standardInput: pipe.fileHandleForReading
    )

    #expect(content == "hello\nworld")
}

@Test func readInputReadsExplicitStdinForDash() async throws {
    let pipe = Pipe()
    pipe.fileHandleForWriting.write(Data("from stdin".utf8))
    pipe.fileHandleForWriting.closeFile()

    let content = try AskAFM.readInput(
        inputFile: "-",
        standardInput: pipe.fileHandleForReading
    )

    #expect(content == "from stdin")
}

@Test func readInputReadsExplicitFileContent() async throws {
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
    try "from file".write(to: fileURL, atomically: true, encoding: .utf8)

    let content = try AskAFM.readInput(inputFile: fileURL.path)

    #expect(content == "from file")
}

@Test func readPromptReadsExplicitPromptFileContent() async throws {
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
    try "prompt from file".write(to: fileURL, atomically: true, encoding: .utf8)

    let prompt = try AskAFM.readPrompt(promptFile: fileURL.path)

    #expect(prompt == "prompt from file")
}

@Test func modelPromptUsesPlainRequestWithoutStdin() async throws {
    let prompt = AskAFM.modelPrompt(
        userRequest: "tell me a joke",
        stdinContent: nil
    )

    #expect(prompt == "tell me a joke")
}

@Test func userPromptPrefersPromptFileContent() async throws {
    let prompt = AskAFM.userPrompt(
        promptFileContent: "prompt from file",
        promptParts: []
    )

    #expect(prompt == "prompt from file")
}

@Test func userPromptJoinsRemainingArgumentsLikeUnixCli() async throws {
    let prompt = AskAFM.userPrompt(
        from: ["summarize", "this", "document"]
    )

    #expect(prompt == "summarize this document")
}

@Test func modelPromptWrapsRequestAndInputForFilterMode() async throws {
    let prompt = AskAFM.modelPrompt(
        userRequest: "summarize this",
        stdinContent: "Line one\nLine two"
    )

    #expect(
        prompt == """
            summarize this

            Input:
            Line one
            Line two
            """
    )
}

@Test func modelPromptLeavesTabularInputOutOfPrompt() async throws {
    let prompt = AskAFM.modelPrompt(
        userRequest: "analyze this table",
        stdinContent: "value,label\n1,a\n2,b",
        tabularData: true
    )

    #expect(prompt == "analyze this table")
}

@Test func tabularDatasetParsesOnlyWhenEnabled() async throws {
    let disabledDataset = try AskAFM.tabularDataset(
        enabled: false,
        stdinContent: "value\n1"
    )
    let enabledDataset = try AskAFM.tabularDataset(
        enabled: true,
        stdinContent: "value\n1"
    )

    #expect(disabledDataset == nil)
    #expect(enabledDataset?.rowCount == 1)
}

@Test func sessionInstructionsIncludeConfiguredFilterInstructions() async throws {
    let configuration = AskAFMConfiguration(
        filterModeInstructions: "Only transform the provided text."
    )

    let instructions = AskAFM.sessionInstructions(configuration: configuration)

    #expect(instructions.contains("Only transform the provided text."))
}

@Test func sessionInstructionsAppendBuiltInToolGuidance() async throws {
    let configuration = AskAFMConfiguration(
        filterModeInstructions: "Only transform the provided text."
    )

    let instructions = AskAFM.sessionInstructions(configuration: configuration)

    #expect(instructions.contains("Only transform the provided text."))
    #expect(instructions.contains("Tools are read-only."))
    #expect(instructions.contains("call tools only for runtime context"))
}

@Test func sessionInstructionsDescribeLoadedTabularData() async throws {
    let dataset = try InsightDataset.parse(
        """
        value,label
        1,a
        2,b
        """
    )
    let instructions = AskAFM.sessionInstructions(
        configuration: .default,
        tabularDataset: dataset
    )

    #expect(instructions.contains("Tabular input loaded: 2 rows, 2 cols."))
    #expect(instructions.contains("tabularData"))
    #expect(instructions.contains("includeInsights"))
    #expect(instructions.contains("analysisSections"))
    #expect(instructions.contains("Raw input omitted"))
}

@Test func generationOptionsUseConfiguredModelSettings() async throws {
    let configuration = AskAFMConfiguration(
        sampling: .greedy,
        temperature: 0.6,
        maximumResponseTokens: 123
    )

    let options = AskAFM.generationOptions(configuration: configuration)

    #expect(options.sampling == .greedy)
    #expect(options.temperature == 0.6)
    #expect(options.maximumResponseTokens == 123)
}

@Test func automaticSamplingLeavesFoundationModelsSamplingUnset() async throws {
    let options = AskAFM.generationOptions(configuration: .default)

    #expect(options.sampling == nil)
}
