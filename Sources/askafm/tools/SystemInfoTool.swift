//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

import Darwin
import Foundation
import FoundationModels
import core

/// A tool that returns basic information about the current system, such as OS version, architecture, and memory.
struct SystemInfoTool: Tool {
    private let logger = AskAFMLogger.systemInfoTool

    let name = "systemInfo"
    let description = "Basic system info."

    @Generable
    struct Arguments {}

    func run() async throws -> String {
        logger.info("Tool invoked: \(name)")
        var systemInfo = utsname()
        uname(&systemInfo)

        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }

        struct SystemInfo: ReflectiveDescription {
            let hostname: String = "\(ProcessInfo.processInfo.hostName)"
            let operatingSystem: String = "macOS"
            let version = SystemInfoTool.operatingSystemVersion
            let versionString: String = "\(ProcessInfo.processInfo.operatingSystemVersionString)"
            let compiledArchitecture: String = {
                #if arch(arm64)
                    return "arm64"
                #elseif arch(x86_64)
                    return "x86_64"
                #else
                    return "unknown"
                #endif
            }()
            let runtimeArchitecture: String
            let isTranslated: Bool = SystemInfoTool.processIsTranslated
            let processorCount: Int = ProcessInfo.processInfo.processorCount
            let activeProcessorCount: Int = ProcessInfo.processInfo.activeProcessorCount
            let physicalMemory: String = ByteCountFormatter.string(
                fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory),
                countStyle: .memory
            )
            let uptime = ProcessInfo.processInfo.systemUptime
            let thermalState: String = {
                switch ProcessInfo.processInfo.thermalState {
                case .nominal:
                    return "nominal"
                case .fair:
                    return "fair"
                case .serious:
                    return "serious"
                case .critical:
                    return "critical"
                @unknown default:
                    return "unknown"
                }
            }()
            let isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        let info = SystemInfo(runtimeArchitecture: machine)
        let description = String(describing: info)
        logger.debug(
            "Returning system information with runtimeArchitecture=\(machine), bytes=\(description.utf8.count)"
        )
        return description
    }

    private static var processIsTranslated: Bool {
        var translated: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname(
            "sysctl.proc_translated",
            &translated,
            &size,
            nil,
            0
        )

        return result == 0 && translated == 1
    }

    private static var operatingSystemVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    func call(arguments: Arguments) async throws -> String {
        try await run()
    }
}
