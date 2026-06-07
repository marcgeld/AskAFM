//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import FoundationModels
import core

/// A tool that returns project credits and acknowledgements.
struct CreditsTool: Tool {
    private let logger = AskAFMLogger.creditsTool

    let name = "creditsTool"
    let description = "AskAFM credits."

    @Generable
    struct Arguments {}

    func run() async throws -> String {
        logger.debug("Generating project credits")
        let response = """
        AskAFM

        Author:
        Marcus Gelderman (marcgeld@gmail.com)

        Built with:
        - Swift
        - FoundationModels
        - Foundation
        - ArgumentParser

        Special Thanks:
        - Apple Foundation Models team
        - Swift open source contributors

        License:
        Apache-2.0

        Homepage:
        https://github.com/marcgeld/askafm
        """
        logger.debug("Returning credits response with \(response.utf8.count) bytes")
        return response
    }

    func call(arguments: Arguments) async throws -> String {
        logger.info("Tool invoked: \(name)")
        return try await run()
    }
}
