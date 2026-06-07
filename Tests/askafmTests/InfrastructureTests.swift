//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Testing

@testable import askafm

private func withTemporaryHomeDirectory(
    _ body: (URL) throws -> Void
) throws {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let homeURL = rootURL.appendingPathComponent("home", isDirectory: true)

    try FileManager.default.createDirectory(
        at: homeURL,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: rootURL)
    }

    try body(homeURL)
}

@Test func reflectiveDescriptionIncludesStoredPropertyNamesAndValues() async throws {
    struct ExampleDescription: ReflectiveDescription {
        let name = "AskAFM"
        let count = 4
    }

    let description = ExampleDescription().description

    #expect(description.contains("name: AskAFM"))
    #expect(description.contains("count: 4"))
}

@Test func configurationWritesDefaultInstructions() async throws {
    try withTemporaryHomeDirectory { homeURL in
        let url = homeURL.appendingPathComponent(AskAFMConfigurationStore.defaultPath)
        try AskAFMConfigurationStore(url: url).writeDefault()
        let data = try Data(contentsOf: url)
        let configuration = try AskAFMConfigurationStore.configuration(from: data)

        #expect(
            configuration.filterModeInstructions
                == AskAFMConfiguration.default.filterModeInstructions
        )
        #expect(configuration.saveSession == false)
        #expect(configuration.sampling == .automatic)
        #expect(configuration.temperature == 0)
        #expect(configuration.maximumResponseTokens == 4096)
        #expect(url == homeURL.appendingPathComponent(AskAFMConfigurationStore.defaultPath))
    }
}

@Test func configurationLoadOrCreateCreatesMissingConfig() async throws {
    try withTemporaryHomeDirectory { homeURL in
        let url = homeURL.appendingPathComponent(AskAFMConfigurationStore.defaultPath)
        let configuration = try AskAFMConfigurationStore(url: url).loadOrCreate()

        #expect(configuration == .default)
        #expect(
            FileManager.default.fileExists(
                atPath: url.path
            )
        )
    }
}

@Test func configurationLoadOrCreateReadsCustomizedInstructions() async throws {
    try withTemporaryHomeDirectory { homeURL in
        let customized = AskAFMConfiguration(
            filterModeInstructions: "Only answer in uppercase.",
            saveSession: true,
            sampling: .greedy,
            temperature: 0.7,
            maximumResponseTokens: 512
        )
        let url = homeURL.appendingPathComponent(AskAFMConfigurationStore.defaultPath)
        let store = AskAFMConfigurationStore(url: url)
        try store.write(customized)

        let configuration = try store.loadOrCreate()
        #expect(configuration == customized)
    }
}

@Test func configurationStoreWritesSessionNextToConfigFile() async throws {
    try withTemporaryHomeDirectory { homeURL in
        let configURL = homeURL.appendingPathComponent(
            AskAFMConfigurationStore.defaultPath
        )
        let store = AskAFMConfigurationStore(url: configURL)
        let sessionURL = try store.writeSession("Transcript entries: 1\n")
        let sessionText = try String(
            decoding: Data(contentsOf: sessionURL),
            as: UTF8.self
        )

        #expect(sessionURL.lastPathComponent == "session.txt")
        #expect(sessionURL.deletingLastPathComponent() == configURL.deletingLastPathComponent())
        #expect(sessionText == "Transcript entries: 1\n")
    }
}

@Test func configurationReadsPartialTOMLFilesWithDefaults() async throws {
    let data = Data(
        """
        saveSession = true
        maximumResponseTokens = 256
        unknownFutureValue = "cloud"
        """.utf8
    )
    let configuration = try AskAFMConfigurationStore.configuration(from: data)

    #expect(
        configuration.filterModeInstructions
            == AskAFMConfiguration.default.filterModeInstructions
    )
    #expect(configuration.saveSession == true)
    #expect(configuration.sampling == .automatic)
    #expect(configuration.temperature == 0)
    #expect(configuration.maximumResponseTokens == 256)
}

@Test func configurationMigratesLegacyDefaultFilterInstructions() async throws {
    let data = AskAFMConfigurationStore.tomlData(
        for: AskAFMConfiguration(
            filterModeInstructions: AskAFMConfiguration.legacyDefaultFilterModeInstructions
        )
    )

    let configuration = try AskAFMConfigurationStore.configuration(from: data)

    #expect(
        configuration.filterModeInstructions
            == AskAFMConfiguration.defaultFilterModeInstructions
    )
}

@Test func configurationLoadOrCreateRemovesUnknownKeysWhenNormalizing() async throws {
    try withTemporaryHomeDirectory { homeURL in
        let url = homeURL.appendingPathComponent(AskAFMConfigurationStore.defaultPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let staleTOML = """
            filterModeInstructions = "Keep this value."
            obsoleteFlag = true
            """
        try Data(staleTOML.utf8).write(to: url, options: .atomic)

        let configuration = try AskAFMConfigurationStore(url: url).loadOrCreate()
        let normalizedTOML = try String(
            decoding: Data(contentsOf: url),
            as: UTF8.self
        )

        #expect(configuration.filterModeInstructions == "Keep this value.")
        #expect(normalizedTOML.contains("filterModeInstructions"))
        #expect(normalizedTOML.contains("saveSession"))
        #expect(normalizedTOML.contains("sampling"))
        #expect(normalizedTOML.contains("temperature"))
        #expect(normalizedTOML.contains("maximumResponseTokens"))
        #expect(normalizedTOML.contains("Keep this value."))
        #expect(normalizedTOML.contains("obsoleteFlag") == false)
    }
}

@Test func configurationReadsSamplingStrategiesFromTOML() async throws {
    let topKData = Data(#"sampling = "randomTopK:40""#.utf8)
    let thresholdData = Data(
        #"sampling = "randomProbabilityThreshold:0.95""#.utf8
    )

    let topKConfiguration = try AskAFMConfigurationStore.configuration(
        from: topKData
    )
    let thresholdConfiguration = try AskAFMConfigurationStore.configuration(
        from: thresholdData
    )

    #expect(topKConfiguration.sampling == .randomTopK(40))
    #expect(
        thresholdConfiguration.sampling == .randomProbabilityThreshold(0.95)
    )
}

@Test func configurationRejectsInvalidGenerationOptions() async throws {
    #expect(throws: AskAFMConfigurationError.invalidTemperature(1.5)) {
        try AskAFMConfigurationStore.configuration(
            from: Data("temperature = 1.5".utf8)
        )
    }

    #expect(throws: AskAFMConfigurationError.invalidMaximumResponseTokens(0)) {
        try AskAFMConfigurationStore.configuration(
            from: Data("maximumResponseTokens = 0".utf8)
        )
    }
}

@Test func configurationLoadOrCreateBackfillsMissingValuesFromCurrentModel() async throws {
    try withTemporaryHomeDirectory { homeURL in
        let url = homeURL.appendingPathComponent(AskAFMConfigurationStore.defaultPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try Data(#"unknownFutureValue = "cloud""#.utf8)
            .write(to: url, options: .atomic)

        let configuration = try AskAFMConfigurationStore(url: url).loadOrCreate()
        let reloaded = try AskAFMConfigurationStore.configuration(
            from: Data(contentsOf: url)
        )

        #expect(configuration == .default)
        #expect(reloaded == .default)
    }
}

@Test func configurationLoadOrCreateReplacesUnreadableConfig() async throws {
    try withTemporaryHomeDirectory { homeURL in
        let url = homeURL.appendingPathComponent(AskAFMConfigurationStore.defaultPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try Data("filterModeInstructions = [".utf8)
            .write(to: url, options: .atomic)

        let configuration = try AskAFMConfigurationStore(url: url).loadOrCreate()
        let reloaded = try AskAFMConfigurationStore.configuration(
            from: Data(contentsOf: url)
        )

        #expect(configuration == .default)
        #expect(reloaded == .default)
    }
}
