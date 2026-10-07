# Swiftix sysutils

This repository provides teaching-oriented system diagnostics for Swiftix. It
follows the same Go module, deterministic builder, native `.pkg`, and
execution-test pattern as the sibling `coreutils` repository, while keeping
diagnostics separate from basic text and file utilities.

The `sysutils_0.1.1.pkg` package contains four independently compiled Swiftix Go
commands:

- `memstat` explains the managed-runtime memory model, system budget, actual heap
  bytes, VFS storage bytes, and per-process reported memory;
- `lsof [pid]` lists immutable descriptor snapshots for files, pipes, terminals,
  devices, and UDP/TCP sockets;
- `pstree` renders the current parent/child process hierarchy; and
- `strace pid` prints the target's last 128 completed Swift-native calls.

## Compatibility and honest limits

The package requires Swiftix 0.13.0 or later and teaching procfs schema 1. The
builder checks the schema against the sibling Swiftix source, and every command
checks `/proc/swiftix` before reading diagnostic files.

These names describe familiar teaching workflows, not full Linux implementations:

- memory is exact Swiftix Go managed-heap accounting. It excludes host RSS,
  virtual address spaces, page faults, swap, native Swift objects, and VFS bytes;
- `lsof` reports the file-description type, access, flags, offsets, sizes, and
  socket/pipe details. A regular VFS inode has no canonical pathname after hard
  links or rename, so it does not invent one;
- `strace` is a bounded snapshot of completed `ProcessContext` calls. It is not a
  live ptrace attachment, does not show Linux syscall numbers, and may omit calls
  outside the instrumented Swift-native boundary; and
- the tools read immutable procfs snapshots and never mutate the target process.

## Sources

```text
Commands/<name>/main.go    one command: `package main`, import path `swiftix/Commands/<name>`
internal/common/common.go  package `common` (`swiftix/internal/common`): procfs reader, schema
                           check, and line and field helpers shared by the commands
userland/userland.go       host stand-in for the runtime package `swiftix/userland`
go.mod                     module `swiftix`
package.json               package name, version, requirements, and command list
```

The repository is one Go module. Each command is its own `package main` and
imports the shared code as an ordinary package:

```go
import "swiftix/internal/common"

processes, status := common.ReadGuestFile("pstree", "/proc/processes")
lines := common.SplitLines(processes)
```

`common` lives under `internal/` because it is an implementation detail of these
commands, not an API for other modules: Go, and Swiftix Go, refuse to import it
from outside this module. Its exported identifiers are the ones commands call;
everything else is unexported.

The package builder compiles each command as a module build: the command's
package plus every local package it imports, linked by the Swiftix Go compiler
into one executable image. A call into `common` costs exactly what a call inside
`package main` costs.

`swiftix/userland` is provided by the Swiftix Go runtime; these commands use its
`ReadInput`. Swiftix Go never compiles the `userland/` directory; it exists so
that a standard Go toolchain can resolve the same import path. That is also why
the module is named `swiftix`, as in `coreutils`: standard Go resolves
`swiftix/userland` only as a directory of a module with that path, so any other
module path would leave the import unresolved on the host.

### Editing with standard Go tools

The sources are valid standard Go as well as valid Swiftix Go, so gopls,
`go build`, `go vet`, and `gofmt` work on the repository as it is. From the
repository root, with Go 1.24 or later installed, these report nothing:

```sh
go build -gcflags=-e ./...
go vet ./...
gofmt -l .
```

A host build is for checking only: the `userland` stand-in does not reproduce the
Swiftix runtime, a host has no teaching procfs, and the commands are tested on
the Swiftix Go virtual machine.

The sources stay within the subset both compilers accept (see
`docs/go-toolchain.md` in the Swiftix repository). The constraints that shape
this code:

- `int` and `byte` are the only numeric types, and there are no rune literals, so
  characters are written as code points (`text[index] == 10`). Indexing a string
  yields a `byte`, as in Go.
- Each import is its own `import "path"` line; a parenthesized import group is
  not accepted.
- Variadic functions cannot be declared, so `common.JoinFields` takes a slice and
  a starting index.

## Building and verification

Building requires Swift 6.3 or later and this sibling layout, with Swiftix at
0.13.0 or later:

```text
swiftixworks/
├── Swiftix/
└── sysutils/
```

Run from the sysutils repository root:

```sh
swift run SysutilsPackageBuilder
swift run SysutilsPackageBuilder --check
swift test -Xswiftc -warnings-as-errors
```

The builder uses the Swiftix Go compiler to produce `swiftix/svm64` executable
images, installs each at `/usr/bin/<command>`, and assembles them with this
README and the license into a deterministic `.pkg` archive with the
`SwiftixPackages` codec.

The archive is written to `Artifacts/<name>_<version>.pkg`, with both values
taken from `package.json`. `--check` rebuilds the package and compares it byte
for byte with that file. Use `--output <path>` to write an archive to another
location.

The tests install the checked-in archive into a fresh Swiftix kernel and run the
commands through the shell, so rebuild the archive before testing a source
change. Because the archive carries this README, editing it also requires a
rebuild.

## License

Swiftix sysutils is available under the [MIT License](LICENSE).
