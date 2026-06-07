//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import FoundationModels
import core

/// A tool that returns the current date, time, and timezone.
struct TimeDateTool: Tool {
    private let logger = AskAFMLogger.currentDateTimeTool

    let name = "currentDateTime"
    let description =
        "Current date/time; optional IANA timezone and format."

    @Generable
    struct Arguments {
        var timezone: String?
        var format: String?
    }

    enum TimeDateToolError: LocalizedError {
        case invalidTimezone(String)

        var errorDescription: String? {
            switch self {
            case .invalidTimezone(let timezone):
                "Invalid timezone identifier: \(timezone)"
            }
        }
    }

    func run(
        now: Date = Date(),
        timezone: String? = nil,
        format: String? = nil
    ) async throws -> String {
        logger.info(
            "Tool invoked: \(name). timezone=\(timezone ?? "auto"), customFormat=\(Self.normalizedFormat(format) != nil)"
        )
        let timeZone = try Self.timeZone(from: timezone)
        let timeZoneLabel = Self.timeZoneLabel(
            from: timezone,
            resolvedTimeZone: timeZone
        )
        let requestedFormat = Self.normalizedFormat(format)

        if let requestedFormat {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = requestedFormat

            let response = """
                Formatted date/time: \(formatter.string(from: now))
                Format: \(requestedFormat)
                Timezone: \(timeZoneLabel)
                """

            logger.debug("Returning formatted date and time for timezone: \(timeZoneLabel)")
            return response
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.autoupdatingCurrent
        dateFormatter.timeZone = timeZone
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale.autoupdatingCurrent
        timeFormatter.timeZone = timeZone
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium

        let response = """
            Current date: \(dateFormatter.string(from: now))
            Current time: \(timeFormatter.string(from: now))
            Timezone: \(timeZoneLabel)
            """

        logger.debug("Returning current date and time for timezone: \(timeZoneLabel)")

        return response
    }

    func call(arguments: Arguments) async throws -> String {
        try await run(
            timezone: arguments.timezone,
            format: arguments.format
        )
    }

    private static func normalizedFormat(_ format: String?) -> String? {
        guard
            let format = format?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ), !format.isEmpty
        else {
            return nil
        }

        return format
    }

    private static func timeZone(from identifier: String?) throws -> TimeZone {
        guard
            let identifier = identifier?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ), !identifier.isEmpty
        else {
            return .autoupdatingCurrent
        }

        guard let timeZone = TimeZone(identifier: identifier) else {
            AskAFMLogger.currentDateTimeTool.error(
                "Invalid timezone requested by currentDateTime: \(identifier)"
            )
            throw TimeDateToolError.invalidTimezone(identifier)
        }

        return timeZone
    }

    private static func timeZoneLabel(
        from identifier: String?,
        resolvedTimeZone: TimeZone
    ) -> String {
        guard
            let identifier = identifier?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ), !identifier.isEmpty
        else {
            return resolvedTimeZone.identifier
        }

        return identifier
    }
}
