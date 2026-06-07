//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import FoundationModels
import core

/// A tool that lists IANA timezones and compares offsets between them.
struct TimeZoneTool: Tool {
    private let logger = AskAFMLogger.timeZoneInfoTool

    let name = "timeZoneInfo"
    let description =
        "List or compare IANA timezones."

    @Generable
    struct Arguments {
        var listAll: Bool?
        var fromTimezone: String?
        var toTimezone: String?
    }

    enum TimeZoneToolError: LocalizedError {
        case invalidTimezone(String)
        case missingTimezonePair

        var errorDescription: String? {
            switch self {
            case .invalidTimezone(let timezone):
                "Invalid timezone identifier: \(timezone)"
            case .missingTimezonePair:
                "Both fromTimezone and toTimezone are required to compare timezones."
            }
        }
    }

    func run(
        listAll: Bool = false,
        fromTimezone: String? = nil,
        toTimezone: String? = nil,
        now: Date = Date()
    ) async throws -> String {
        logger.info(
            "Tool invoked: \(name). listAll=\(listAll), fromTimezone=\(fromTimezone ?? "none"), toTimezone=\(toTimezone ?? "none")"
        )
        if listAll {
            logger.debug("Listing all known timezones")
            return Self.listAllTimezones()
        }

        let hasFromTimezone = Self.normalizedIdentifier(fromTimezone) != nil
        let hasToTimezone = Self.normalizedIdentifier(toTimezone) != nil

        guard hasFromTimezone || hasToTimezone else {
            logger.debug("Returning timezone summary because no timezone arguments were supplied")
            return Self.timezoneSummary()
        }

        guard hasFromTimezone && hasToTimezone else {
            logger.error("Timezone comparison requested with only one timezone")
            throw TimeZoneToolError.missingTimezonePair
        }

        let from = try Self.timeZone(from: fromTimezone)
        let to = try Self.timeZone(from: toTimezone)
        let fromLabel = Self.timeZoneLabel(
            from: fromTimezone,
            resolvedTimeZone: from
        )
        let toLabel = Self.timeZoneLabel(
            from: toTimezone,
            resolvedTimeZone: to
        )
        let difference =
            to.secondsFromGMT(for: now)
            - from.secondsFromGMT(for: now)

        logger.debug(
            "Comparing timezone offset from \(fromLabel) to \(toLabel)"
        )

        return """
            From timezone: \(fromLabel)
            To timezone: \(toLabel)
            Offset difference: \(Self.formattedOffset(difference))
            \(Self.comparisonSentence(
                fromLabel: fromLabel,
                toLabel: toLabel,
                difference: difference
            ))
            """
    }

    func call(arguments: Arguments) async throws -> String {
        try await run(
            listAll: arguments.listAll ?? false,
            fromTimezone: arguments.fromTimezone,
            toTimezone: arguments.toTimezone
        )
    }

    private static func listAllTimezones() -> String {
        let identifiers = Set(TimeZone.knownTimeZoneIdentifiers + ["UTC"])
            .sorted()

        return """
            Known timezones (\(identifiers.count)):
            \(identifiers.joined(separator: "\n"))
            """
    }

    private static func timezoneSummary() -> String {
        """
        Known timezone count: \(TimeZone.knownTimeZoneIdentifiers.count)
        Set listAll to true to list all known timezones.
        Provide both fromTimezone and toTimezone to compare their current offset.
        """
    }

    private static func timeZone(from identifier: String?) throws -> TimeZone {
        guard let identifier = normalizedIdentifier(identifier) else {
            throw TimeZoneToolError.missingTimezonePair
        }

        guard let timeZone = TimeZone(identifier: identifier) else {
            AskAFMLogger.timeZoneInfoTool.error(
                "Invalid timezone requested by timeZoneInfo: \(identifier)"
            )
            throw TimeZoneToolError.invalidTimezone(identifier)
        }

        return timeZone
    }

    private static func normalizedIdentifier(_ identifier: String?) -> String? {
        guard
            let identifier = identifier?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ), !identifier.isEmpty
        else {
            return nil
        }

        return identifier
    }

    private static func timeZoneLabel(
        from identifier: String?,
        resolvedTimeZone: TimeZone
    ) -> String {
        normalizedIdentifier(identifier) ?? resolvedTimeZone.identifier
    }

    private static func formattedOffset(_ seconds: Int) -> String {
        let sign = seconds >= 0 ? "+" : "-"
        let absoluteSeconds = abs(seconds)
        let hours = absoluteSeconds / 3_600
        let minutes = (absoluteSeconds % 3_600) / 60

        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }

    private static func comparisonSentence(
        fromLabel: String,
        toLabel: String,
        difference: Int
    ) -> String {
        guard difference != 0 else {
            return "\(toLabel) has the same current offset as \(fromLabel)."
        }

        let absoluteSeconds = abs(difference)
        let hours = absoluteSeconds / 3_600
        let minutes = (absoluteSeconds % 3_600) / 60
        let direction = difference > 0 ? "ahead of" : "behind"

        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours) \(hours == 1 ? "hour" : "hours")")
        }
        if minutes > 0 {
            parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
        }

        return "\(toLabel) is \(parts.joined(separator: " ")) \(direction) \(fromLabel)."
    }
}
