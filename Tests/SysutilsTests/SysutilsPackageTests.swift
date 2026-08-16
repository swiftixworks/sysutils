import Foundation
import Swiftix
import SwiftixGoRuntime
import SwiftixPackages
import Testing

@Suite("sysutils package")
struct SysutilsPackageTests {
    @Test("checked-in archive contains every svm64 diagnostic")
    func archiveContents() throws {
        let archive = try loadArchive()

        #expect(archive.manifest.name == "sysutils")
        #expect(archive.manifest.version.description == "0.1.0")
        #expect(archive.manifest.architecture == "svm64")
        let commandPaths = Set(commandNames.map { "/usr/bin/" + $0 })
        #expect(Set(archive.files.map(\.path)) == commandPaths.union([
            "/usr/share/doc/sysutils/LICENSE",
            "/usr/share/doc/sysutils/README.md",
        ]))
        for entry in archive.files where commandPaths.contains(entry.path) {
            #expect(entry.mode == 0o755)
            #expect(GoExecutableImage.recognizes(archive.contents(of: entry)))
        }
    }

    @Test("diagnostics consume the real versioned procfs surface")
    func diagnosticsExecute() throws {
        let archive = try loadArchive()
        let loop = EventLoop()
        let kernel = Kernel(loop: loop, runtimeMemoryLimitBytes: 1_048_576)
        install(archive, in: kernel, loop: loop)

        final class Box { var workerPID: PID = 0 }
        let box = Box()
        kernel.spawn("worker") { context in
            box.workerPID = context.getpid()
            let descriptor = context.open("/lesson", create: true)!
            _ = context.write(descriptor, Array("hello".utf8))
            _ = context.seek(descriptor, to: 0, whence: 0)
            let socket = context.socket()!
            _ = context.bind(socket, address: nil, port: 4_242)
            context.sleep(10) { context.exit(0) }
        }
        loop.advance(by: 0)

        let terminal = PseudoTerminal()
        terminal.echo = false
        var output: [UInt8] = []
        terminal.onOutput = { [weak terminal] in
            guard let terminal else { return }
            output.append(contentsOf: terminal.readForApp(max: 65_535))
        }
        let commands = CommandRegistry.builtins
        GoExecutableLoader.register(in: commands)
        kernel.spawn("sh", Programs.shell(tty: terminal.slave, commands: commands))
        loop.advance(by: 0)

        for line in [
            "memstat",
            "lsof \(box.workerPID)",
            "strace \(box.workerPID)",
            "pstree",
        ] {
            terminal.writeFromApp(Array((line + "\n").utf8))
            loop.advance(by: 0)
        }

        let rendered = String(decoding: output, as: UTF8.self)
        #expect(rendered.contains("MODEL managed-runtime"))
        #expect(rendered.contains("TOTAL_KB 1024"))
        #expect(rendered.contains("PID NAME FD TYPE ACCESS FLAGS OFFSET SIZE DETAIL"))
        #expect(rendered.contains("\(box.workerPID) worker 0 file read-write"))
        #expect(rendered.contains("\(box.workerPID) worker 1 udp read-write"))
        #expect(rendered.contains("# model swift-native-completed history=128"))
        #expect(rendered.contains(" open 0 path=/lesson"))
        #expect(rendered.contains(" bind 0 fd=1,port=4242"))
        #expect(rendered.contains("worker(\(box.workerPID))"))
    }

    private var commandNames: [String] {
        ["lsof", "memstat", "pstree", "strace"]
    }

    private func install(_ archive: PackageArchive, in kernel: Kernel, loop: EventLoop) {
        kernel.spawn("install-sysutils") { context in
            _ = context.mkdir("/usr")
            _ = context.mkdir("/usr/bin")
            for entry in archive.files where entry.path.hasPrefix("/usr/bin/") {
                let descriptor = context.open(entry.path, create: true, truncate: true)!
                context.write(descriptor, archive.contents(of: entry))
                context.close(descriptor)
                _ = context.chmod(entry.path, mode: FileMode(rawValue: entry.mode))
            }
            context.exit(0)
        }
        loop.runUntilIdle()
    }

    private func loadArchive() throws -> PackageArchive {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let bytes = Array(try Data(contentsOf: root
            .appendingPathComponent("Artifacts/sysutils_0.1.0.pkg")))
        return try PackageArchive.decode(bytes)
    }
}
