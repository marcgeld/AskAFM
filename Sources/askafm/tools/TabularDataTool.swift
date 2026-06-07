//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import FoundationModels
import core

/// A read-only view over tabular stdin that has already been parsed into a
/// `TabularData.DataFrame`.
struct TabularDataTool: Tool, CustomStringConvertible, CustomDebugStringConvertible {
    private let logger = AskAFMLogger.tabularDataTool
    private let dataset: InsightDataset

    let name = "tabularData"
    let description =
        "Inspect loaded tabular data, list available analyses, or run selected analyses."

    @Generable
    struct Arguments {
        var includeRows: Bool?
        var rowLimit: Int?
        var includeInsights: Bool?
        var analysisSections: String?
    }

    init(dataset: InsightDataset) {
        self.dataset = dataset
    }

    var debugDescription: String {
        "\(name)(rows: \(dataset.rowCount), columns: \(dataset.columns.count), format: \(dataset.inputFormat))"
    }

    func run(
        includeRows: Bool = false,
        rowLimit: Int = 10,
        includeInsights: Bool = false,
        analysisSections: String? = nil
    ) async throws -> String {
        logger.info(
            "Tool invoked: \(name). includeRows=\(includeRows), includeInsights=\(includeInsights), analysisSections=\(analysisSections ?? "none"), requestedRowLimit=\(rowLimit)"
        )
        logger.debug(
            "Returning tabular data view for \(dataset.rowCount) rows and \(dataset.columns.count) columns"
        )
        let safeRowLimit = max(0, min(rowLimit, 50))

        var sections = [
            """
            Tabular dataset
            Format: \(dataset.inputFormat)
            Rows: \(dataset.rowCount)
            Columns: \(dataset.columns.count)
            """,
            columnSummary(),
        ]

        if includeRows {
            sections.append(rowPreview(limit: safeRowLimit))
        }

        let requestedAnalysisSections = Self.analysisSections(from: analysisSections)
        if includeInsights || requestedAnalysisSections.isEmpty == false {
            sections.append(
                try insightSummary(requestedSections: requestedAnalysisSections)
            )
        }

        let response = sections.joined(separator: "\n\n")
        logger.debug("Returning tabular data view with \(response.utf8.count) bytes")
        return response
    }

    func call(arguments: Arguments) async throws -> String {
        try await run(
            includeRows: arguments.includeRows ?? false,
            rowLimit: arguments.rowLimit ?? 10,
            includeInsights: arguments.includeInsights ?? false,
            analysisSections: arguments.analysisSections
        )
    }

    private func columnSummary() -> String {
        let lines = dataset.columns.map { column in
            let nonMissing = column.nonMissingValues
            let samples = nonMissing.prefix(3).joined(separator: ", ")
            return "- \(column.name): \(detectedType(for: column)), non-missing \(nonMissing.count), missing \(dataset.rowCount - nonMissing.count), samples: \(samples)"
        }

        return "Columns:\n" + lines.joined(separator: "\n")
    }

    private func rowPreview(limit: Int) -> String {
        let rows = dataset.rows
            .prefix(limit)
            .enumerated()
            .map { index, row in
                let cells = dataset.columns.enumerated().map { columnIndex, column in
                    let value = columnIndex < row.count ? row[columnIndex] : nil
                    return "\(column.name)=\(value ?? "")"
                }
                .joined(separator: ", ")
                return "\(index + 1). \(cells)"
            }

        return rows.isEmpty
            ? "Rows: none"
            : "Rows:\n" + rows.joined(separator: "\n")
    }

    private func insightSummary(requestedSections: Set<String>) throws -> String {
        guard requestedSections.isEmpty == false else {
            return availableAnalysisSections()
        }

        let report = try InsightView(loadedDataset: dataset).run()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )

        let lines = try requestedSections.sorted().map { section in
            let value = try insightSection(section, from: report)
            let data = try encoder.encode(value)
            return "\(section):\n\(String(decoding: data, as: UTF8.self))"
        }

        return "Insights:\n" + lines.joined(separator: "\n\n")
    }

    private func availableAnalysisSections() -> String {
        """
        Available analyses:
        - quality
        - summary
        - distributions
        - benford
        - zipf
        - pareto
        - normality
        - uniformity
        - outliers
        - relationships
        - summaryText
        Pass analysisSections as a comma-separated list to run selected analyses.
        """
    }

    private static func analysisSections(from value: String?) -> Set<String> {
        guard let value else {
            return []
        }

        return Set(
            value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { $0.isEmpty == false }
        )
    }

    private func insightSection(
        _ section: String,
        from report: InsightReport
    ) throws -> any Encodable {
        switch section {
        case "quality":
            return report.dataQuality
        case "summary", "statistics":
            return report.summaryStatistics
        case "distributions", "distribution":
            return report.distributionCharacteristics
        case "benford":
            return report.benfordAnalysis
        case "zipf":
            return report.zipfAnalysis
        case "pareto":
            return report.paretoAnalysis
        case "normality":
            return report.normalityAnalysis
        case "uniformity":
            return report.uniformityAnalysis
        case "outliers", "outlier":
            return report.outlierAnalysis
        case "relationships", "relationship":
            return report.relationshipAnalysis
        case "summarytext", "insightsummary":
            return report.insightSummary
        default:
            return ["error": "Unknown analysis section: \(section)"]
        }
    }

    private func detectedType(for column: InsightColumn) -> String {
        let nonMissing = column.nonMissingValues
        guard nonMissing.isEmpty == false else {
            return "empty"
        }

        if column.numericValues.count == nonMissing.count {
            return "numeric"
        }

        let lowercased = nonMissing.map { $0.lowercased() }
        if lowercased.allSatisfy({ ["true", "false", "yes", "no", "0", "1"].contains($0) }) {
            return "boolean-like"
        }

        if nonMissing.count > 1 && Set(nonMissing).count <= max(2, nonMissing.count / 2) {
            return "categorical"
        }

        return "text"
    }
}
