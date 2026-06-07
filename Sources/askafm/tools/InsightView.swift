//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import TabularData
import core

/// A read-only statistical microscope for tabular text data.
struct InsightView {
    private let logger = AskAFMLogger.insightViewTool
    private let loadedDataset: InsightDataset?

    enum InsightViewError: LocalizedError {
        case emptyInput
        case unsupportedInput

        var errorDescription: String? {
            switch self {
            case .emptyInput:
                "InsightView requires tabular dataset."
            case .unsupportedInput:
                "Input must be CSV, TSV, or JSON tabular text."
            }
        }
    }

    init(loadedDataset: InsightDataset? = nil) {
        self.loadedDataset = loadedDataset
    }

    func run(inputText: String? = nil) throws -> InsightReport {
        logger.info("Insight analysis started. inlineInputProvided=\(inputText != nil)")
        let dataset = try dataset(from: inputText)
        logger.debug(
            "Analyzing dataset with \(dataset.rowCount) rows and \(dataset.columns.count) columns"
        )
        let report = InsightAnalyzer.analyze(dataset)
        logger.debug(
            "Insight report generated for \(report.rowCount) rows, \(report.columnCount) columns"
        )
        return report
    }

    func reportJSON(inputText: String? = nil) throws -> String {
        let report = try run(inputText: inputText)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        let data = try encoder.encode(report)
        return String(decoding: data, as: UTF8.self)
    }

    private func dataset(from inputText: String?) throws -> InsightDataset {
        if let inputText,
            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        {
            logger.debug("Parsing inline insightView input with \(inputText.utf8.count) bytes")
            return try InsightDataset.parse(inputText)
        }

        guard let loadedDataset else {
            logger.error("insightView invoked without inline input or loaded dataset")
            throw InsightViewError.emptyInput
        }

        logger.debug("Using preloaded insightView dataset")
        return loadedDataset
    }
}

struct InsightReport: Codable, Equatable {
    let inputFormat: String
    let rowCount: Int
    let columnCount: Int
    let dataQuality: DataQualityAnalysis
    let summaryStatistics: [ColumnSummaryStatistics]
    let distributionCharacteristics: [DistributionCharacteristics]
    let benfordAnalysis: [BenfordAnalysis]
    let zipfAnalysis: [ZipfAnalysis]
    let paretoAnalysis: [ParetoAnalysis]
    let normalityAnalysis: [StatisticalFitAnalysis]
    let uniformityAnalysis: [StatisticalFitAnalysis]
    let outlierAnalysis: [OutlierAnalysis]
    let relationshipAnalysis: RelationshipAnalysis
    let insightSummary: InsightSummary
}

struct DataQualityAnalysis: Codable, Equatable {
    let missingCellCount: Int
    let duplicateRowCount: Int
    let sparseColumns: [String]
    let constantColumns: [String]
    let nullLikeValueCount: Int
    let invalidValueCount: Int
    let suspiciousValues: [String]
    let detectedColumnTypes: [String: String]
    let columns: [ColumnQuality]
    let qualityScore: Double
    let assessment: String
}

struct ColumnQuality: Codable, Equatable {
    let column: String
    let missingValues: Int
    let uniqueValues: Int
    let cardinality: Int
    let sparse: Bool
    let constant: Bool
    let nullLikeValues: Int
    let invalidValues: Int
    let suspiciousValues: [String]
    let detectedType: String
}

struct ColumnSummaryStatistics: Codable, Equatable {
    let column: String
    let sampleCount: Int
    let minimum: Double?
    let maximum: Double?
    let range: Double?
    let mean: Double?
    let median: Double?
    let mode: Double?
    let variance: Double?
    let standardDeviation: Double?
    let assessment: String
}

struct DistributionCharacteristics: Codable, Equatable {
    let column: String
    let skewness: Double?
    let kurtosis: Double?
    let interpretation: [String]
}

struct BenfordAnalysis: Codable, Equatable {
    let column: String
    let observedFrequencies: [String: Double]
    let expectedFrequencies: [String: Double]
    let chiSquareStatistic: Double?
    let confidenceAssessment: String
}

struct ZipfAnalysis: Codable, Equatable {
    let column: String
    let fittedExponent: Double?
    let goodnessOfFitScore: Double?
    let confidenceAssessment: String
}

struct ParetoAnalysis: Codable, Equatable {
    let column: String
    let paretoExponent: Double?
    let top20PercentContribution: Double?
    let top10PercentContribution: Double?
    let concentrationAssessment: String
}

struct StatisticalFitAnalysis: Codable, Equatable {
    let column: String
    let testStatistic: Double?
    let pValue: Double?
    let confidenceAssessment: String
}

struct OutlierAnalysis: Codable, Equatable {
    let column: String
    let outlierCount: Int
    let outlierValues: [Double]
    let severityAssessment: String
}

struct RelationshipAnalysis: Codable, Equatable {
    let pearsonCorrelationMatrix: [String: [String: Double]]
    let spearmanCorrelationMatrix: [String: [String: Double]]
    let strongestPositiveRelationships: [RelationshipFinding]
    let strongestNegativeRelationships: [RelationshipFinding]
    let trendDirection: [String: String]
    let growthRate: [String: Double]
    let redundantColumns: [RelationshipFinding]
    let assessment: String
}

struct RelationshipFinding: Codable, Equatable {
    let leftColumn: String
    let rightColumn: String
    let value: Double
}

struct InsightSummary: Codable, Equatable {
    let overallDataQuality: String
    let dominantDistributionCharacteristics: [String]
    let benfordFindings: [String]
    let zipfFindings: [String]
    let paretoFindings: [String]
    let outlierFindings: [String]
    let relationshipFindings: [String]
    let unusualObservations: [String]
    let potentialConcerns: [String]
    let conciseExplanation: String
}

struct InsightDataset: @unchecked Sendable {
    private static let logger = AskAFMLogger.tabularData

    let dataFrame: DataFrame
    let inputFormat: String
    let columns: [InsightColumn]
    let rows: [[String?]]

    var rowCount: Int {
        rows.count
    }

    static func parse(_ input: String) throws -> InsightDataset {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.error("Cannot parse empty tabular input")
            throw InsightView.InsightViewError.emptyInput
        }

        let parsed: ParsedTable
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            logger.debug("Detected JSON-like tabular input")
            parsed = try parseJSON(trimmed)
        } else {
            logger.debug("Detected delimited tabular input")
            parsed = try parseDelimited(trimmed)
        }

        guard !parsed.headers.isEmpty else {
            logger.error("Parsed tabular input without headers")
            throw InsightView.InsightViewError.unsupportedInput
        }

        let canonicalCSV = csvText(headers: parsed.headers, rows: parsed.rows)
        let dataFrame = try DataFrame(csvData: Data(canonicalCSV.utf8))
        let columns = parsed.headers.enumerated().map { index, header in
            InsightColumn(
                name: header,
                values: parsed.rows.map { row in
                    guard index < row.count else { return nil }
                    return normalizedCell(row[index])
                }
            )
        }

        let dataset = InsightDataset(
            dataFrame: dataFrame,
            inputFormat: parsed.format,
            columns: columns,
            rows: parsed.rows.map { row in
                parsed.headers.indices.map { index in
                    guard index < row.count else { return nil }
                    return normalizedCell(row[index])
                }
            }
        )
        logger.info(
            "Created DataFrame from \(dataset.inputFormat) with \(dataset.rowCount) rows and \(dataset.columns.count) columns"
        )
        return dataset
    }

    private static func parseDelimited(_ input: String) throws -> ParsedTable {
        let delimiter = input.contains("\t") ? "\t" : ","
        let records = parseSeparatedRecords(input, delimiter: Character(delimiter))
        guard let headers = records.first, !headers.isEmpty else {
            throw InsightView.InsightViewError.unsupportedInput
        }

        return ParsedTable(
            headers: headers.map(cleanHeader),
            rows: Array(records.dropFirst()),
            format: delimiter == "\t" ? "tsv" : "csv"
        )
    }

    private static func parseJSON(_ input: String) throws -> ParsedTable {
        let data = Data(input.utf8)
        let object = try JSONSerialization.jsonObject(with: data)

        if let rows = object as? [[String: Any]] {
            return table(fromObjectRows: rows, format: "json")
        }

        if let dictionary = object as? [String: Any] {
            if let rows = dictionary.values.first(where: { $0 is [[String: Any]] })
                as? [[String: Any]]
            {
                return table(fromObjectRows: rows, format: "json")
            }

            if dictionary.values.allSatisfy({ $0 is [Any] }) {
                return table(fromColumnDictionary: dictionary, format: "json")
            }

            return table(fromObjectRows: [dictionary], format: "json")
        }

        throw InsightView.InsightViewError.unsupportedInput
    }

    private static func table(
        fromObjectRows objectRows: [[String: Any]],
        format: String
    ) -> ParsedTable {
        var headers: [String] = []
        for row in objectRows {
            for key in row.keys.sorted() where !headers.contains(key) {
                headers.append(key)
            }
        }

        let rows = objectRows.map { row in
            headers.map { stringify(row[$0]) }
        }

        return ParsedTable(headers: headers, rows: rows, format: format)
    }

    private static func table(
        fromColumnDictionary dictionary: [String: Any],
        format: String
    ) -> ParsedTable {
        let headers = dictionary.keys.sorted()
        let columns = headers.map { dictionary[$0] as? [Any] ?? [] }
        let rowCount = columns.map(\.count).max() ?? 0
        let rows = (0..<rowCount).map { rowIndex in
            columns.map { column in
                guard rowIndex < column.count else { return "" }
                return stringify(column[rowIndex])
            }
        }

        return ParsedTable(headers: headers, rows: rows, format: format)
    }

    private static func stringify(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else {
            return ""
        }

        if let string = value as? String {
            return string
        }

        if JSONSerialization.isValidJSONObject(value),
            let data = try? JSONSerialization.data(withJSONObject: value),
            let string = String(data: data, encoding: .utf8)
        {
            return string
        }

        return String(describing: value)
    }

    private static func parseSeparatedRecords(
        _ input: String,
        delimiter: Character
    ) -> [[String]] {
        var records: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = input.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if inQuotes, let next = iterator.next() {
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        inQuotes = false
                        if next == delimiter {
                            row.append(field)
                            field = ""
                        } else if next == "\n" {
                            row.append(field)
                            records.append(row)
                            row = []
                            field = ""
                        } else if next != "\r" {
                            field.append(next)
                        }
                    }
                } else {
                    inQuotes.toggle()
                }
            } else if character == delimiter, !inQuotes {
                row.append(field)
                field = ""
            } else if character == "\n", !inQuotes {
                row.append(field)
                records.append(row)
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
        }

        row.append(field)
        if !row.allSatisfy({ $0.isEmpty }) {
            records.append(row)
        }

        return records
    }

    private static func csvText(headers: [String], rows: [[String]]) -> String {
        ([headers] + rows)
            .map { row in row.map(csvEscape).joined(separator: ",") }
            .joined(separator: "\n")
    }

    private static func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n")
        else {
            return field
        }

        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func cleanHeader(_ header: String) -> String {
        let cleaned = header.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "column" : cleaned
    }

    private static func normalizedCell(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct InsightColumn {
    let name: String
    let values: [String?]

    var numericValues: [Double] {
        values.compactMap { value in
            guard let value else { return nil }
            return Double(value.replacingOccurrences(of: ",", with: "."))
        }
    }

    var nonMissingValues: [String] {
        values.compactMap { $0 }
    }
}

struct ParsedTable {
    let headers: [String]
    let rows: [[String]]
    let format: String
}

enum InsightAnalyzer {
    static func analyze(_ dataset: InsightDataset) -> InsightReport {
        let quality = dataQuality(dataset)
        let summaries = dataset.columns.map(summaryStatistics)
        let distributions = dataset.columns.map(distributionCharacteristics)
        let benford = dataset.columns.map(benfordAnalysis)
        let zipf = dataset.columns.map(zipfAnalysis)
        let pareto = dataset.columns.map(paretoAnalysis)
        let normality = dataset.columns.map(normalityAnalysis)
        let uniformity = dataset.columns.map(uniformityAnalysis)
        let outliers = dataset.columns.map(outlierAnalysis)
        let relationships = relationshipAnalysis(dataset)
        let summary = insightSummary(
            quality: quality,
            distributions: distributions,
            benford: benford,
            zipf: zipf,
            pareto: pareto,
            outliers: outliers,
            relationships: relationships
        )

        return InsightReport(
            inputFormat: dataset.inputFormat,
            rowCount: dataset.rowCount,
            columnCount: dataset.columns.count,
            dataQuality: quality,
            summaryStatistics: summaries,
            distributionCharacteristics: distributions,
            benfordAnalysis: benford,
            zipfAnalysis: zipf,
            paretoAnalysis: pareto,
            normalityAnalysis: normality,
            uniformityAnalysis: uniformity,
            outlierAnalysis: outliers,
            relationshipAnalysis: relationships,
            insightSummary: summary
        )
    }

    private static func dataQuality(_ dataset: InsightDataset) -> DataQualityAnalysis {
        let duplicateRows = Dictionary(grouping: dataset.rows, by: { $0 })
            .values
            .reduce(0) { count, rows in count + max(0, rows.count - 1) }
        let columns = dataset.columns.map(columnQuality)
        let missing = columns.reduce(0) { $0 + $1.missingValues }
        let nullLike = columns.reduce(0) { $0 + $1.nullLikeValues }
        let invalid = columns.reduce(0) { $0 + $1.invalidValues }
        let sparse = columns.filter(\.sparse).map(\.column)
        let constant = columns.filter(\.constant).map(\.column)
        let suspicious = columns.flatMap { column in
            column.suspiciousValues.map { "\(column.column): \($0)" }
        }
        let cells = max(1, dataset.rowCount * max(1, dataset.columns.count))
        let penalty = Double(missing + nullLike + invalid + duplicateRows)
            / Double(cells)
        let qualityScore = max(0, min(1, 1 - penalty))
        let assessment = if qualityScore >= 0.9 {
            "high quality"
        } else if qualityScore >= 0.7 {
            "usable with minor concerns"
        } else if qualityScore >= 0.5 {
            "usable with caution"
        } else {
            "low quality"
        }

        return DataQualityAnalysis(
            missingCellCount: missing,
            duplicateRowCount: duplicateRows,
            sparseColumns: sparse,
            constantColumns: constant,
            nullLikeValueCount: nullLike,
            invalidValueCount: invalid,
            suspiciousValues: suspicious,
            detectedColumnTypes: Dictionary(
                uniqueKeysWithValues: columns.map { ($0.column, $0.detectedType) }
            ),
            columns: columns,
            qualityScore: rounded(qualityScore),
            assessment: assessment
        )
    }

    private static func columnQuality(_ column: InsightColumn) -> ColumnQuality {
        let values = column.values
        let missing = values.filter { $0 == nil }.count
        let nonMissing = column.nonMissingValues
        let unique = Set(nonMissing)
        let nullLike = nonMissing.filter(isNullLike).count
        let numericCount = column.numericValues.count
        let invalid = nonMissing.isEmpty ? 0 : nonMissing.count - numericCount
        let detectedType = detectedType(for: column)
        let sparse = !values.isEmpty && Double(missing) / Double(values.count) > 0.5
        let constant = unique.count == 1 && values.count > 1
        var suspicious: [String] = []
        if constant {
            suspicious.append("constant column")
        }
        if sparse {
            suspicious.append("mostly missing")
        }
        if detectedType == "numeric", invalid > 0 {
            suspicious.append("mixed numeric and non-numeric values")
        }
        if values.count > 0,
            Double(unique.count) / Double(values.count) > 0.95,
            values.count > 20
        {
            suspicious.append("very high cardinality")
        }

        return ColumnQuality(
            column: column.name,
            missingValues: missing,
            uniqueValues: unique.count,
            cardinality: unique.count,
            sparse: sparse,
            constant: constant,
            nullLikeValues: nullLike,
            invalidValues: detectedType == "numeric" ? invalid : 0,
            suspiciousValues: suspicious,
            detectedType: detectedType
        )
    }

    private static func summaryStatistics(
        _ column: InsightColumn
    ) -> ColumnSummaryStatistics {
        let values = column.numericValues
        guard !values.isEmpty else {
            return ColumnSummaryStatistics(
                column: column.name,
                sampleCount: 0,
                minimum: nil,
                maximum: nil,
                range: nil,
                mean: nil,
                median: nil,
                mode: nil,
                variance: nil,
                standardDeviation: nil,
                assessment: "not numeric"
            )
        }

        let minValue = values.min()
        let maxValue = values.max()
        let variance = variance(values)
        return ColumnSummaryStatistics(
            column: column.name,
            sampleCount: values.count,
            minimum: minValue.map(rounded),
            maximum: maxValue.map(rounded),
            range: minValue.flatMap { minimum in
                maxValue.map { maximum in rounded(maximum - minimum) }
            },
            mean: rounded(mean(values)),
            median: rounded(median(values)),
            mode: mode(values).map(rounded),
            variance: rounded(variance),
            standardDeviation: rounded(sqrt(variance)),
            assessment: values.count >= 3 ? "numeric summary calculated" : "small numeric sample"
        )
    }

    private static func distributionCharacteristics(
        _ column: InsightColumn
    ) -> DistributionCharacteristics {
        let values = column.numericValues
        guard values.count >= 3 else {
            return DistributionCharacteristics(
                column: column.name,
                skewness: nil,
                kurtosis: nil,
                interpretation: ["insufficient numeric data"]
            )
        }

        let skew = skewness(values)
        let kurt = kurtosis(values)
        var interpretation: [String] = []
        if abs(skew) < 0.5 {
            interpretation.append("symmetric")
        } else if skew > 0 {
            interpretation.append("right skewed")
        } else {
            interpretation.append("left skewed")
        }
        if kurt > 1 {
            interpretation.append("heavy tailed")
        } else if kurt < -1 {
            interpretation.append("light tailed")
        }

        return DistributionCharacteristics(
            column: column.name,
            skewness: rounded(skew),
            kurtosis: rounded(kurt),
            interpretation: interpretation
        )
    }

    private static func benfordAnalysis(_ column: InsightColumn) -> BenfordAnalysis {
        let digits = column.numericValues
            .map(abs)
            .filter { $0 > 0 && $0.isFinite }
            .compactMap(firstDigit)
        let observedCounts = Dictionary(grouping: digits, by: { $0 })
            .mapValues(\.count)
        let total = max(1, digits.count)
        let expected = Dictionary(
            uniqueKeysWithValues: (1...9).map {
                (String($0), rounded(log10(1 + 1 / Double($0))))
            }
        )
        let observed = Dictionary(
            uniqueKeysWithValues: (1...9).map {
                (String($0), rounded(Double(observedCounts[$0] ?? 0) / Double(total)))
            }
        )

        guard digits.count >= 10 else {
            return BenfordAnalysis(
                column: column.name,
                observedFrequencies: observed,
                expectedFrequencies: expected,
                chiSquareStatistic: nil,
                confidenceAssessment: "insufficient data"
            )
        }

        let chiSquare = (1...9).reduce(0.0) { result, digit in
            let expectedCount = pow(10, log10(1 + 1 / Double(digit)))
                * Double(total)
            let observedCount = Double(observedCounts[digit] ?? 0)
            return result + pow(observedCount - expectedCount, 2) / expectedCount
        }

        return BenfordAnalysis(
            column: column.name,
            observedFrequencies: observed,
            expectedFrequencies: expected,
            chiSquareStatistic: rounded(chiSquare),
            confidenceAssessment: chiSquare < 15.51 ? "consistent with Benford" : "deviates from Benford"
        )
    }

    private static func zipfAnalysis(_ column: InsightColumn) -> ZipfAnalysis {
        let frequencies = Dictionary(grouping: column.nonMissingValues, by: { $0 })
            .mapValues(\.count)
            .values
            .sorted(by: >)
        guard frequencies.count >= 3 else {
            return ZipfAnalysis(
                column: column.name,
                fittedExponent: nil,
                goodnessOfFitScore: nil,
                confidenceAssessment: "insufficient rank-frequency data"
            )
        }

        let ranks = (1...frequencies.count).map { log(Double($0)) }
        let counts = frequencies.map { log(Double($0)) }
        let fit = linearFit(x: ranks, y: counts)
        let exponent = -fit.slope

        return ZipfAnalysis(
            column: column.name,
            fittedExponent: rounded(exponent),
            goodnessOfFitScore: rounded(fit.rSquared),
            confidenceAssessment: fit.rSquared > 0.8 ? "strong Zipf-like structure" : "weak Zipf-like structure"
        )
    }

    private static func paretoAnalysis(_ column: InsightColumn) -> ParetoAnalysis {
        let values = column.numericValues
            .map(abs)
            .filter { $0 > 0 && $0.isFinite }
            .sorted(by: >)
        guard values.count >= 5 else {
            return ParetoAnalysis(
                column: column.name,
                paretoExponent: nil,
                top20PercentContribution: nil,
                top10PercentContribution: nil,
                concentrationAssessment: "insufficient numeric data"
            )
        }

        let total = values.reduce(0, +)
        let top20 = contribution(values, fraction: 0.2, total: total)
        let top10 = contribution(values, fraction: 0.1, total: total)
        let minimum = values.min() ?? 1
        let exponent = Double(values.count)
            / values.reduce(0) { $0 + log($1 / minimum) }

        return ParetoAnalysis(
            column: column.name,
            paretoExponent: rounded(exponent),
            top20PercentContribution: rounded(top20),
            top10PercentContribution: rounded(top10),
            concentrationAssessment: top20 >= 0.8 ? "strong Pareto concentration" : "moderate or weak concentration"
        )
    }

    private static func normalityAnalysis(
        _ column: InsightColumn
    ) -> StatisticalFitAnalysis {
        let values = column.numericValues
        guard values.count >= 8 else {
            return StatisticalFitAnalysis(
                column: column.name,
                testStatistic: nil,
                pValue: nil,
                confidenceAssessment: "insufficient numeric data"
            )
        }

        let skew = skewness(values)
        let kurt = kurtosis(values)
        let statistic = Double(values.count) / 6 * (pow(skew, 2) + pow(kurt, 2) / 4)
        let pValue = exp(-statistic / 2)

        return StatisticalFitAnalysis(
            column: column.name,
            testStatistic: rounded(statistic),
            pValue: rounded(pValue),
            confidenceAssessment: pValue > 0.05 ? "normal-like" : "unlikely normal"
        )
    }

    private static func uniformityAnalysis(
        _ column: InsightColumn
    ) -> StatisticalFitAnalysis {
        let values = column.numericValues.sorted()
        guard values.count >= 5,
            let minimum = values.first,
            let maximum = values.last,
            maximum > minimum
        else {
            return StatisticalFitAnalysis(
                column: column.name,
                testStatistic: nil,
                pValue: nil,
                confidenceAssessment: "insufficient numeric data"
            )
        }

        let scaled = values.map { ($0 - minimum) / (maximum - minimum) }
        let statistic = scaled.enumerated().map { index, value in
            abs(value - Double(index + 1) / Double(values.count))
        }.max() ?? 0
        let pValue = min(1, 2 * exp(-2 * Double(values.count) * pow(statistic, 2)))

        return StatisticalFitAnalysis(
            column: column.name,
            testStatistic: rounded(statistic),
            pValue: rounded(pValue),
            confidenceAssessment: pValue > 0.05 ? "uniform-like" : "unlikely uniform"
        )
    }

    private static func outlierAnalysis(_ column: InsightColumn) -> OutlierAnalysis {
        let values = column.numericValues
        guard values.count >= 4 else {
            return OutlierAnalysis(
                column: column.name,
                outlierCount: 0,
                outlierValues: [],
                severityAssessment: "insufficient numeric data"
            )
        }

        let sorted = values.sorted()
        let q1 = quantile(sorted, probability: 0.25)
        let q3 = quantile(sorted, probability: 0.75)
        let iqr = q3 - q1
        let lower = q1 - 1.5 * iqr
        let upper = q3 + 1.5 * iqr
        let average = mean(values)
        let deviation = sqrt(variance(values))
        let outliers = Set(
            values.filter { value in
                value < lower || value > upper
                    || (deviation > 0 && abs((value - average) / deviation) > 3)
            }
        )

        let severity = if outliers.isEmpty {
            "none detected"
        } else if Double(outliers.count) / Double(values.count) > 0.1 {
            "high"
        } else {
            "moderate"
        }

        return OutlierAnalysis(
            column: column.name,
            outlierCount: outliers.count,
            outlierValues: outliers.sorted().map(rounded),
            severityAssessment: severity
        )
    }

    private static func relationshipAnalysis(
        _ dataset: InsightDataset
    ) -> RelationshipAnalysis {
        let numericColumns = dataset.columns.filter { $0.numericValues.count >= 3 }
        guard numericColumns.count >= 2 else {
            return RelationshipAnalysis(
                pearsonCorrelationMatrix: [:],
                spearmanCorrelationMatrix: [:],
                strongestPositiveRelationships: [],
                strongestNegativeRelationships: [],
                trendDirection: [:],
                growthRate: [:],
                redundantColumns: [],
                assessment: "insufficient numeric columns"
            )
        }

        var pearson: [String: [String: Double]] = [:]
        var spearman: [String: [String: Double]] = [:]
        var findings: [RelationshipFinding] = []

        for left in numericColumns {
            for right in numericColumns {
                let paired = pairedNumericValues(left, right)
                let pearsonValue = correlation(paired.map(\.0), paired.map(\.1))
                let spearmanValue = spearmanCorrelation(paired.map(\.0), paired.map(\.1))
                pearson[left.name, default: [:]][right.name] = rounded(pearsonValue)
                spearman[left.name, default: [:]][right.name] = rounded(spearmanValue)
                if left.name < right.name {
                    findings.append(
                        RelationshipFinding(
                            leftColumn: left.name,
                            rightColumn: right.name,
                            value: rounded(pearsonValue)
                        )
                    )
                }
            }
        }

        let positive = findings
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0 }
        let negative = findings
            .filter { $0.value < 0 }
            .sorted { $0.value < $1.value }
            .prefix(3)
            .map { $0 }
        let redundant = findings.filter { abs($0.value) >= 0.98 }
        let trend = Dictionary(
            uniqueKeysWithValues: numericColumns.map {
                ($0.name, trendDirection($0.numericValues))
            }
        )
        let growth: [String: Double] = Dictionary(
            uniqueKeysWithValues: numericColumns.compactMap { column in
                guard let rate = growthRate(column.numericValues) else { return nil }
                return (column.name, rounded(rate))
            }
        )

        return RelationshipAnalysis(
            pearsonCorrelationMatrix: pearson,
            spearmanCorrelationMatrix: spearman,
            strongestPositiveRelationships: Array(positive),
            strongestNegativeRelationships: Array(negative),
            trendDirection: trend,
            growthRate: growth,
            redundantColumns: redundant,
            assessment: findings.isEmpty ? "no relationships found" : "relationships analyzed"
        )
    }

    private static func insightSummary(
        quality: DataQualityAnalysis,
        distributions: [DistributionCharacteristics],
        benford: [BenfordAnalysis],
        zipf: [ZipfAnalysis],
        pareto: [ParetoAnalysis],
        outliers: [OutlierAnalysis],
        relationships: RelationshipAnalysis
    ) -> InsightSummary {
        let dominant = distributions.flatMap { distribution in
            distribution.interpretation.map { "\(distribution.column): \($0)" }
        }
        let benfordFindings = benford.map {
            "\($0.column): \($0.confidenceAssessment)"
        }
        let zipfFindings = zipf.map {
            "\($0.column): \($0.confidenceAssessment)"
        }
        let paretoFindings = pareto.map {
            "\($0.column): \($0.concentrationAssessment)"
        }
        let outlierFindings = outliers
            .filter { $0.outlierCount > 0 }
            .map { "\($0.column): \($0.outlierCount) outliers" }
        let relationshipFindings = relationships.strongestPositiveRelationships
            .map { "\($0.leftColumn) vs \($0.rightColumn): \($0.value)" }
        let concerns = quality.suspiciousValues + outlierFindings
        let explanation = """
            Data quality is \(quality.assessment). Dominant distribution signals: \(dominant.prefix(4).joined(separator: "; ")). Benford: \(benfordFindings.prefix(3).joined(separator: "; ")). Pareto: \(paretoFindings.prefix(3).joined(separator: "; ")). Relationships: \(relationships.assessment).
            """

        return InsightSummary(
            overallDataQuality: quality.assessment,
            dominantDistributionCharacteristics: dominant,
            benfordFindings: benfordFindings,
            zipfFindings: zipfFindings,
            paretoFindings: paretoFindings,
            outlierFindings: outlierFindings,
            relationshipFindings: relationshipFindings,
            unusualObservations: quality.suspiciousValues,
            potentialConcerns: concerns,
            conciseExplanation: explanation
        )
    }

    private static func detectedType(for column: InsightColumn) -> String {
        let values = column.nonMissingValues
        guard !values.isEmpty else { return "empty" }
        let numeric = column.numericValues.count
        if numeric == values.count {
            return "numeric"
        }
        if values.allSatisfy({ ["true", "false", "yes", "no", "0", "1"].contains($0.lowercased()) }) {
            return "boolean"
        }
        return "string"
    }

    private static func isNullLike(_ value: String) -> Bool {
        ["null", "nil", "na", "n/a", "nan", "none", "missing", "-"]
            .contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func firstDigit(_ value: Double) -> Int? {
        var number = value
        while number >= 10 { number /= 10 }
        while number < 1 { number *= 10 }
        let digit = Int(number.rounded(.down))
        return (1...9).contains(digit) ? digit : nil
    }

    private static func contribution(
        _ values: [Double],
        fraction: Double,
        total: Double
    ) -> Double {
        guard total > 0 else { return 0 }
        let count = max(1, Int(ceil(Double(values.count) * fraction)))
        return values.prefix(count).reduce(0, +) / total
    }

    private static func pairedNumericValues(
        _ left: InsightColumn,
        _ right: InsightColumn
    ) -> [(Double, Double)] {
        zip(left.values, right.values).compactMap { leftValue, rightValue in
            guard let leftValue,
                let rightValue,
                let leftNumber = Double(leftValue.replacingOccurrences(of: ",", with: ".")),
                let rightNumber = Double(rightValue.replacingOccurrences(of: ",", with: "."))
            else {
                return nil
            }
            return (leftNumber, rightNumber)
        }
    }

    private static func correlation(_ left: [Double], _ right: [Double]) -> Double {
        guard left.count == right.count, left.count >= 2 else { return 0 }
        let leftMean = mean(left)
        let rightMean = mean(right)
        let numerator = zip(left, right).reduce(0) {
            $0 + (($1.0 - leftMean) * ($1.1 - rightMean))
        }
        let leftDenominator = sqrt(left.reduce(0) { $0 + pow($1 - leftMean, 2) })
        let rightDenominator = sqrt(right.reduce(0) { $0 + pow($1 - rightMean, 2) })
        let denominator = leftDenominator * rightDenominator
        return denominator == 0 ? 0 : numerator / denominator
    }

    private static func spearmanCorrelation(_ left: [Double], _ right: [Double]) -> Double {
        correlation(ranks(left), ranks(right))
    }

    private static func ranks(_ values: [Double]) -> [Double] {
        let sorted = values.enumerated().sorted { $0.element < $1.element }
        var ranks = Array(repeating: 0.0, count: values.count)
        for (rank, pair) in sorted.enumerated() {
            ranks[pair.offset] = Double(rank + 1)
        }
        return ranks
    }

    private static func trendDirection(_ values: [Double]) -> String {
        guard values.count >= 2 else { return "unknown" }
        let fit = linearFit(
            x: values.indices.map(Double.init),
            y: values
        )
        if abs(fit.slope) < 0.000_001 {
            return "flat"
        }
        return fit.slope > 0 ? "increasing" : "decreasing"
    }

    private static func growthRate(_ values: [Double]) -> Double? {
        guard let first = values.first, let last = values.last, first != 0 else {
            return nil
        }
        return (last - first) / abs(first)
    }

    private static func mean(_ values: [Double]) -> Double {
        values.reduce(0, +) / Double(values.count)
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func mode(_ values: [Double]) -> Double? {
        let grouped = Dictionary(grouping: values, by: { $0 })
            .mapValues(\.count)
        guard let best = grouped.max(by: { $0.value < $1.value }),
            best.value > 1
        else {
            return nil
        }
        return best.key
    }

    private static func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let average = mean(values)
        return values.reduce(0) { $0 + pow($1 - average, 2) }
            / Double(values.count - 1)
    }

    private static func skewness(_ values: [Double]) -> Double {
        let average = mean(values)
        let deviation = sqrt(variance(values))
        guard deviation > 0 else { return 0 }
        return values.reduce(0) { $0 + pow(($1 - average) / deviation, 3) }
            / Double(values.count)
    }

    private static func kurtosis(_ values: [Double]) -> Double {
        let average = mean(values)
        let deviation = sqrt(variance(values))
        guard deviation > 0 else { return 0 }
        return values.reduce(0) { $0 + pow(($1 - average) / deviation, 4) }
            / Double(values.count) - 3
    }

    private static func quantile(_ sorted: [Double], probability: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let position = probability * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        if lower == upper {
            return sorted[lower]
        }
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }

    private static func linearFit(
        x: [Double],
        y: [Double]
    ) -> (slope: Double, rSquared: Double) {
        guard x.count == y.count, x.count >= 2 else {
            return (0, 0)
        }

        let xMean = mean(x)
        let yMean = mean(y)
        let numerator = zip(x, y).reduce(0) {
            $0 + (($1.0 - xMean) * ($1.1 - yMean))
        }
        let denominator = x.reduce(0) { $0 + pow($1 - xMean, 2) }
        let slope = denominator == 0 ? 0 : numerator / denominator
        let intercept = yMean - slope * xMean
        let residual = zip(x, y).reduce(0) {
            $0 + pow($1.1 - (intercept + slope * $1.0), 2)
        }
        let total = y.reduce(0) { $0 + pow($1 - yMean, 2) }
        let rSquared = total == 0 ? 0 : 1 - residual / total
        return (slope, max(0, min(1, rSquared)))
    }

    private static func rounded(_ value: Double) -> Double {
        guard value.isFinite else { return value }
        return (value * 1_000_000).rounded() / 1_000_000
    }
}
