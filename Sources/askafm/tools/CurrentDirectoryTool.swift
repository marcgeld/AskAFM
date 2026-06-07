//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import FoundationModels
import core

/// A tool that returns the current working directory of the process.
struct CurrentDirectoryTool: Tool {
    private let logger = AskAFMLogger.currentDirectoryTool

    let name = "currentDirectory"
    let description = "Current working directory."

    @Generable
    struct Arguments {}

    func run() async throws -> String {
        logger.info("Tool invoked: \(name)")
        let cwd = FileManager.default.currentDirectoryPath
        logger.debug("Returning current directory: \(cwd)")
        return cwd
    }

    func call(arguments: Arguments) async throws -> String {
        try await run()
    }
}
