//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import OSLog

/// A centralized logger for the AskAFM application, providing categorized loggers for different components.
public enum AskAFMLogger {
    public static let subsystem = "com.marcgeld.askafm"

    public static let cli = Logger(
        subsystem: subsystem,
        category: "CLI"
    )

    public static let configuration = Logger(
        subsystem: subsystem,
        category: "Configuration"
    )

    public static let core = Logger(
        subsystem: subsystem,
        category: "Core"
    )

    public static let model = Logger(
        subsystem: subsystem,
        category: "Model"
    )

    public static let tabularData = Logger(
        subsystem: subsystem,
        category: "TabularData"
    )

    public static let tools = Logger(
        subsystem: subsystem,
        category: "Tools"
    )

    public static let currentDirectoryTool = tool(category: "currentDirectory")
    public static let currentDateTimeTool = tool(category: "currentDateTime")
    public static let timeZoneInfoTool = tool(category: "timeZoneInfo")
    public static let insightViewTool = tool(category: "insightView")
    public static let tabularDataTool = tool(category: "tabularData")
    public static let systemInfoTool = tool(category: "systemInfo")
    public static let creditsTool = tool(category: "creditsTool")

    private static func tool(category: String) -> Logger {
        Logger(
            subsystem: subsystem,
            category: "Tool.\(category)"
        )
    }
}
