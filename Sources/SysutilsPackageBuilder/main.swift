/// Deterministically compiles the Go command sources of the teaching
/// diagnostics and packages their svm64 executable images into a
/// Swiftix-native `.pkg` archive.

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

/// Directory, relative to the module root, that holds one package per command.
private let commandDirectory = "Commands"

private struct Arguments {
    let check: Bool
    let outputURL: URL?

    init(_ raw: [String]) throws {
        var check = false
        var outputURL: URL?
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

/// The checked-in artifact for `specification`: one archive per package version.
private func defaultOutputURL(_ specification: PackageSpecification) -> URL {
    repositoryRoot.appendingPathComponent(
        "Artifacts/\(specification.name)_\(specification.version).pkg")
}

/// The module path declared by `go.mod`, which prefixes every local import.
private func loadModulePath() throws -> String {
    let text = try String(
        contentsOf: repositoryRoot.appendingPathComponent("go.mod"), encoding: .utf8)
    for line in text.split(separator: "\n") {
        let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        if fields.count == 2, fields[0] == "module" { return String(fields[1]) }
    }
    throw BuilderError.invalidSpecification("go.mod has no module declaration")
}

/// The sources of the package `importPath` of this module, or nil when the
/// module has no such directory.
///
/// Files are listed in name order and addressed by their path relative to the
/// repository root, so the archive does not depend on where the checkout is.
/// The compiler never asks for `swiftix/userland`: the Swiftix runtime provides
/// that package, and the `userland/` directory is only a host stand-in.
private func packageSources(_ importPath: String, modulePath: String) throws -> [GoSourceFile]? {
    guard importPath.hasPrefix(modulePath + "/") else { return nil }
    let relativeDirectory = String(importPath.dropFirst(modulePath.count + 1))
    guard relativeDirectory.split(separator: "/", omittingEmptySubsequences: false)
        .allSatisfy({ safeComponent(String($0)) })
    else { return nil }
    let directory = repositoryRoot.appendingPathComponent(relativeDirectory)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
        isDirectory.boolValue
    else { return nil }
    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        .filter { $0.hasSuffix(".go") && !$0.hasSuffix("_test.go") && !$0.hasPrefix(".") }
        .sorted()
    return try names.map { name in
        let url = directory.appendingPathComponent(name)
        let type = try FileManager.default.attributesOfItem(atPath: url.path)[.type]
        guard type as? FileAttributeType == .typeRegular else {
            throw BuilderError.invalidSpecification(
                "\(relativeDirectory)/\(name) is not a regular file")
        }
        return GoSourceFile(
            path: "\(relativeDirectory)/\(name)",
            text: try String(contentsOf: url, encoding: .utf8))
    }
}

private func buildArchive(_ specification: PackageSpecification) throws -> [UInt8] {
    let modulePath = try loadModulePath()
    var files: [(path: String, mode: UInt16, bytes: [UInt8])] = []
    for command in specification.commands {
        // Each command is a module build: its `package main` plus every local
        // package it imports, linked into one executable image.
        let executable = try GoCompiler.compile(
            root: "\(modulePath)/\(commandDirectory)/\(command)"
        ) { importPath in
            try packageSources(importPath, modulePath: modulePath)
        }
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
    let specification = try loadSpecification()
    let outputURL = arguments.outputURL ?? defaultOutputURL(specification)
    let bytes = try buildArchive(specification)
    if arguments.check {
        guard FileManager.default.fileExists(atPath: outputURL.path),
            try Data(contentsOf: outputURL) == Data(bytes)
        else {
            throw BuilderError.staleArtifact(outputURL.path)
        }
        print("verified \(outputURL.path)")
    } else {
        try write(bytes, to: outputURL)
        print("wrote \(outputURL.path)")
    }
} catch {
    FileHandle.standardError.write(Data("SysutilsPackageBuilder: \(error)\n".utf8))
    Foundation.exit(1)
}
