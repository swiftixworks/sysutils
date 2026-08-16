/// Deterministically compile the teaching diagnostics and package their svm64
/// images into a Swiftix-native archive.

import Foundation
import Swiftix
import SwiftixGo
import SwiftixGoRuntime
import SwiftixPackages

private struct PackageSpecification: Decodable {
    let schemaVersion: Int
    let name: String
    let version: String
    let architecture: String
    let minimumSwiftixVersion: String
    let procfsSchemaVersion: Int
    let summary: String
    let details: String
    let commands: [String]
}

private enum BuilderError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case invalidSpecification(String)
    case staleArtifact(String)

    var description: String {
        switch self {
        case .invalidArgument(let message), .invalidSpecification(let message):
            return message
        case .staleArtifact(let path):
            return "sysutils package is stale; regenerate \(path)"
        }
    }
}

private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let specificationURL = repositoryRoot.appendingPathComponent("package.json")
private let defaultOutputURL = repositoryRoot
    .appendingPathComponent("Artifacts/sysutils_0.1.0.pkg")

private struct Arguments {
    let check: Bool
    let outputURL: URL

    init(_ raw: [String]) throws {
        var check = false
        var outputURL = defaultOutputURL
        var index = 0
        while index < raw.count {
            switch raw[index] {
            case "--check":
                check = true
            case "--output":
                index += 1
                guard index < raw.count else {
                    throw BuilderError.invalidArgument("--output requires a path")
                }
                outputURL = URL(fileURLWithPath: raw[index], relativeTo: repositoryRoot)
                    .standardizedFileURL
            default:
                throw BuilderError.invalidArgument("unknown argument \(raw[index])")
            }
            index += 1
        }
        self.check = check
        self.outputURL = outputURL
    }
}

private func safeComponent(_ value: String) -> Bool {
    !value.isEmpty && value != "." && value != ".."
        && !value.contains("/") && !value.contains("\0")
}

private func loadSpecification() throws -> PackageSpecification {
    let specification = try JSONDecoder().decode(
        PackageSpecification.self,
        from: Data(contentsOf: specificationURL))
    guard specification.schemaVersion == 1,
        PackageManifest.isValidName(specification.name),
        PackageVersion(specification.version) != nil,
        PackageVersion(specification.minimumSwiftixVersion) != nil,
        specification.procfsSchemaVersion == Swiftix.teachingProcfsSchemaVersion,
        !specification.architecture.isEmpty,
        specification.commands == specification.commands.sorted(),
        Set(specification.commands).count == specification.commands.count,
        specification.commands.allSatisfy(safeComponent)
    else {
        throw BuilderError.invalidSpecification("invalid sysutils package specification")
    }
    return specification
}

private func source(at relativePath: String) throws -> String {
    let url = repositoryRoot.appendingPathComponent(relativePath).standardizedFileURL
    guard url.path.hasPrefix(repositoryRoot.path + "/") else {
        throw BuilderError.invalidSpecification("source path escapes repository")
    }
    return try String(contentsOf: url, encoding: .utf8)
}

private func buildArchive(_ specification: PackageSpecification) throws -> [UInt8] {
    let commonPath = "Commands/common/main.go"
    let commonSource = try source(at: commonPath)
    var files: [(path: String, mode: UInt16, bytes: [UInt8])] = []
    for command in specification.commands {
        let commandPath = "Commands/\(command)/main.go"
        let executable = try GoCompiler.compile(sources: [
            GoSourceFile(path: commonPath, text: commonSource),
            GoSourceFile(path: commandPath, text: try source(at: commandPath)),
        ])
        files.append((
            path: "/usr/bin/\(command)",
            mode: 0o755,
            bytes: try GoExecutableImage.encode(executable)))
    }
    for (sourcePath, guestPath) in [
        ("LICENSE", "/usr/share/doc/sysutils/LICENSE"),
        ("README.md", "/usr/share/doc/sysutils/README.md"),
    ] {
        files.append((
            path: guestPath,
            mode: 0o644,
            bytes: Array(try Data(contentsOf: repositoryRoot.appendingPathComponent(sourcePath)))))
    }

    guard let version = PackageVersion(specification.version) else {
        throw BuilderError.invalidSpecification("invalid package version")
    }
    let manifest = PackageManifest(
        name: specification.name,
        version: version,
        architecture: specification.architecture,
        summary: specification.summary,
        details: specification.details)
    return try PackageArchive.build(manifest: manifest, files: files).encoded()
}

private func write(_ bytes: [UInt8], to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true)
    try Data(bytes).write(to: url, options: .atomic)
}

do {
    let arguments = try Arguments(Array(CommandLine.arguments.dropFirst()))
    let bytes = try buildArchive(loadSpecification())
    if arguments.check {
        guard FileManager.default.fileExists(atPath: arguments.outputURL.path),
            try Data(contentsOf: arguments.outputURL) == Data(bytes)
        else {
            throw BuilderError.staleArtifact(arguments.outputURL.path)
        }
        print("verified \(arguments.outputURL.path)")
    } else {
        try write(bytes, to: arguments.outputURL)
        print("wrote \(arguments.outputURL.path)")
    }
} catch {
    FileHandle.standardError.write(Data("SysutilsPackageBuilder: \(error)\n".utf8))
    Foundation.exit(1)
}
