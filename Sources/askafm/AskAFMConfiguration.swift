//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import TOMLKit
import core

enum AskAFMSamplingStrategy: Equatable {
    case automatic
    case greedy
    case randomTopK(Int)
    case randomProbabilityThreshold(Double)

    init(tomlValue: String) throws {
        let parts = tomlValue.split(separator: ":", maxSplits: 1)
        guard let strategy = parts.first else {
            throw AskAFMConfigurationError.invalidSampling(tomlValue)
        }
        let name = strategy.lowercased()

        switch name {
        case "automatic", "default":
            self = .automatic
        case "greedy":
            self = .greedy
        case "randomtopk":
            guard
                parts.count == 2,
                let topK = Int(parts[1]),
                topK > 0
            else {
                throw AskAFMConfigurationError.invalidSampling(tomlValue)
            }
            self = .randomTopK(topK)
        case "randomprobabilitythreshold":
            guard
                parts.count == 2,
                let threshold = Double(parts[1]),
                (0...1).contains(threshold)
            else {
                throw AskAFMConfigurationError.invalidSampling(tomlValue)
            }
            self = .randomProbabilityThreshold(threshold)
        default:
            throw AskAFMConfigurationError.invalidSampling(tomlValue)
        }
    }

    var tomlValue: String {
        switch self {
        case .automatic:
            return "automatic"
        case .greedy:
            return "greedy"
        case .randomTopK(let topK):
            return "randomTopK:\(topK)"
        case .randomProbabilityThreshold(let threshold):
            return "randomProbabilityThreshold:\(threshold)"
        }
    }
}

enum AskAFMConfigurationError: Error, Equatable {
    case invalidType(key: String)
    case invalidSampling(String)
    case invalidTemperature(Double)
    case invalidMaximumResponseTokens(Int)
}

struct AskAFMConfiguration: Equatable {
    static let legacyDefaultFilterModeInstructions = """
        You are a Unix-style text processing tool.
        Transform only the text the user provides.
        If input text is included, operate only on that supplied input.
        Do not assume filesystem access, shell access, tool access, or directory context.
        Return the transformed result directly.
        """

    static let defaultFilterModeInstructions = """
        Unix text filter. Use only supplied input. Return only the result.
        """

    static let `default` = AskAFMConfiguration()

    var filterModeInstructions: String
    var saveSession: Bool
    var sampling: AskAFMSamplingStrategy
    var temperature: Double
    var maximumResponseTokens: Int

    init(
        filterModeInstructions: String = Self.defaultFilterModeInstructions,
        saveSession: Bool = false,
        sampling: AskAFMSamplingStrategy = .automatic,
        temperature: Double = 0,
        maximumResponseTokens: Int = 4096
    ) {
        self.filterModeInstructions = filterModeInstructions
        self.saveSession = saveSession
        self.sampling = sampling
        self.temperature = temperature
        self.maximumResponseTokens = maximumResponseTokens
    }

    /// Applies values that are explicitly present in a partial config file.
    mutating func applyOverrides(
        from overrides: AskAFMPartialConfiguration
    ) {
        if let filterModeInstructions = overrides.filterModeInstructions {
            self.filterModeInstructions =
                filterModeInstructions == Self.legacyDefaultFilterModeInstructions
                ? Self.defaultFilterModeInstructions
                : filterModeInstructions
        }
        if let saveSession = overrides.saveSession {
            self.saveSession = saveSession
        }
        if let sampling = overrides.sampling {
            self.sampling = sampling
        }
        if let temperature = overrides.temperature {
            self.temperature = temperature
        }
        if let maximumResponseTokens = overrides.maximumResponseTokens {
            self.maximumResponseTokens = maximumResponseTokens
        }
    }
}

/// Optional user overrides read from a potentially partial TOML config file.
struct AskAFMPartialConfiguration {
    let filterModeInstructions: String?
    let saveSession: Bool?
    let sampling: AskAFMSamplingStrategy?
    let temperature: Double?
    let maximumResponseTokens: Int?
}

/// Reads, writes, and normalizes AskAFM's TOML configuration file.
struct AskAFMConfigurationStore {
    static let defaultPath = ".askafm/config.toml"
    static let sessionFileName = "session.txt"

    private let logger = AskAFMLogger.configuration
    private let fileManager: FileManager
    let url: URL

    var sessionURL: URL {
        url.deletingLastPathComponent()
            .appendingPathComponent(Self.sessionFileName)
    }

    init(
        url: URL = AskAFMConfigurationStore.defaultURL(),
        fileManager: FileManager = .default
    ) {
        self.url = url
        self.fileManager = fileManager
    }

    /// The default configuration file URL, typically `~/.askafm/config.toml`.
    static func defaultURL(
        fileManager: FileManager = .default
    ) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(defaultPath)
    }

    /// Loads the configuration if possible, otherwise creates a fresh default.
    ///
    /// Every successful call writes the current model back to disk. This keeps
    /// user files normalized: missing recognized values are backfilled and
    /// unknown values are removed.
    func loadOrCreate() throws -> AskAFMConfiguration {
        let configuration: AskAFMConfiguration
        do {
            configuration = try read()
            logger.info("Loaded configuration from \(url.path)")
        } catch {
            configuration = .default
            logger.warning(
                "Could not read configuration at \(url.path). Writing defaults. Error: \(String(describing: error))"
            )
        }

        try write(configuration)
        logger.debug("Configuration normalized at \(url.path)")
        return configuration
    }

    @discardableResult
    func writeDefault() throws -> URL {
        let writtenURL = try write(.default)
        logger.info("Wrote default configuration to \(writtenURL.path)")
        return writtenURL
    }

    @discardableResult
    func write(_ configuration: AskAFMConfiguration) throws -> URL {
        logger.debug("Writing configuration to \(url.path)")
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = Self.tomlData(for: configuration)
        try data.write(to: url, options: .atomic)
        logger.debug("Wrote \(data.count) configuration bytes to \(url.path)")
        return url
    }

    @discardableResult
    func writeSession(_ transcript: String) throws -> URL {
        logger.debug("Writing session transcript to \(sessionURL.path)")
        try fileManager.createDirectory(
            at: sessionURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try Data(transcript.utf8).write(to: sessionURL, options: .atomic)
        logger.info("Wrote session transcript to \(sessionURL.path)")
        return sessionURL
    }

    private func read() throws -> AskAFMConfiguration {
        if fileManager.fileExists(atPath: url.path) {
            logger.debug("Reading configuration from \(url.path)")
            let data = try Data(contentsOf: url)
            logger.debug("Read \(data.count) configuration bytes from \(url.path)")
            return try Self.configuration(from: data)
        }

        throw CocoaError(.fileNoSuchFile)
    }

    /// Converts any recognizable config attributes into the current model.
    ///
    /// Loading deliberately starts from the current defaults and then overlays
    /// recognized keys from the file. That makes partial configs safe:
    /// known settings survive, unknown settings disappear, and newly added
    /// settings receive the current defaults.
    static func configuration(from data: Data) throws -> AskAFMConfiguration {
        var configuration = AskAFMConfiguration.default
        let overrides = try overrides(from: data)
        configuration.applyOverrides(from: overrides)

        return configuration
    }

    static func tomlData(for configuration: AskAFMConfiguration) -> Data {
        let table = TOMLTable()
        table["filterModeInstructions"] = configuration.filterModeInstructions
        table["saveSession"] = configuration.saveSession
        table["sampling"] = configuration.sampling.tomlValue
        table["temperature"] = configuration.temperature
        table["maximumResponseTokens"] = configuration.maximumResponseTokens
        return Data(table.convert(to: .toml).utf8)
    }

    static func overrides(from data: Data) throws -> AskAFMPartialConfiguration {
        let text = String(decoding: data, as: UTF8.self)
        let table = try TOMLTable(string: text)

        return AskAFMPartialConfiguration(
            filterModeInstructions: try stringValue(
                for: "filterModeInstructions",
                in: table
            ),
            saveSession: try boolValue(for: "saveSession", in: table),
            sampling: try samplingValue(for: "sampling", in: table),
            temperature: try temperatureValue(for: "temperature", in: table),
            maximumResponseTokens: try maximumResponseTokensValue(
                for: "maximumResponseTokens",
                in: table
            )
        )
    }

    private static func stringValue(
        for key: String,
        in table: TOMLTable
    ) throws -> String? {
        try value(for: key, in: table, read: \.string)
    }

    private static func boolValue(
        for key: String,
        in table: TOMLTable
    ) throws -> Bool? {
        try value(for: key, in: table, read: \.bool)
    }

    private static func value<T>(
        for key: String,
        in table: TOMLTable,
        read: (any TOMLValueConvertible) -> T?
    ) throws -> T? {
        guard let value = table[key] else {
            return nil
        }
        guard let typedValue = read(value) else {
            throw AskAFMConfigurationError.invalidType(key: key)
        }
        return typedValue
    }

    private static func samplingValue(
        for key: String,
        in table: TOMLTable
    ) throws -> AskAFMSamplingStrategy? {
        guard let value = try stringValue(for: key, in: table) else {
            return nil
        }
        return try AskAFMSamplingStrategy(tomlValue: value)
    }

    private static func temperatureValue(
        for key: String,
        in table: TOMLTable
    ) throws -> Double? {
        guard let value = table[key] else {
            return nil
        }

        let temperature = value.double ?? value.int.map(Double.init)
        guard let temperature else {
            throw AskAFMConfigurationError.invalidType(key: key)
        }
        guard (0...1).contains(temperature) else {
            throw AskAFMConfigurationError.invalidTemperature(temperature)
        }
        return temperature
    }

    private static func maximumResponseTokensValue(
        for key: String,
        in table: TOMLTable
    ) throws -> Int? {
        guard let value = table[key] else {
            return nil
        }
        guard let maximumResponseTokens = value.int else {
            throw AskAFMConfigurationError.invalidType(key: key)
        }
        guard maximumResponseTokens > 0 else {
            throw AskAFMConfigurationError.invalidMaximumResponseTokens(
                maximumResponseTokens
            )
        }
        return maximumResponseTokens
    }
}
