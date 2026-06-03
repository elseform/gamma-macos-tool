#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

import Foundation

func usage() -> String {
    """
    Usage:
      gamma-setup-engine preflight --request-file PATH
      gamma-setup-engine create --request-file PATH
      gamma-setup-engine install-dependencies --request-file PATH
      gamma-setup-engine install-dependency --name sikarugir|winetricks --request-file PATH
    """
}

func argumentValue(_ name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}

func loadRequest(from arguments: [String]) throws -> SetupRequest {
    guard let path = argumentValue("--request-file", in: arguments) else {
        throw SetupEngineError.message("--request-file is required")
    }
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(SetupRequest.self, from: data)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    FileHandle.standardError.write(Data((usage() + "\n").utf8))
    exit(2)
}

let reporter = JSONEventReporter()
let engine = GAMMASetupEngine(executablePath: CommandLine.arguments[0], reporter: reporter)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

do {
    switch command {
    case "preflight":
        let request = try loadRequest(from: arguments)
        let report = try engine.preflight(request: request)
        let data = try encoder.encode(report)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    case "create":
        let request = try loadRequest(from: arguments)
        try engine.create(request: request)
    case "install-dependencies":
        let request = try loadRequest(from: arguments)
        try engine.installDependencies(request: request)
    case "install-dependency":
        let request = try loadRequest(from: arguments)
        guard let name = argumentValue("--name", in: arguments) else {
            throw SetupEngineError.message("--name is required")
        }
        try engine.installDependency(name: name, request: request)
    case "-h", "--help":
        print(usage())
    default:
        throw SetupEngineError.message("unknown command: \(command)")
    }
} catch {
    let message: String
    if let setup = error as? SetupEngineError {
        message = setup.description
    } else {
        message = error.localizedDescription
    }
    reporter.completed(success: false, message: message)
    FileHandle.standardError.write(Data(("error: \(message)\n").utf8))
    exit(1)
}
