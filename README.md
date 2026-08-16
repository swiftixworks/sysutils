# Swiftix sysutils

This repository provides teaching-oriented system diagnostics for Swiftix. It
follows the same source, deterministic builder, native `.pkg`, and execution-test
pattern as the sibling `coreutils` repository, while keeping diagnostics separate
from basic text and file utilities.

The `sysutils_0.1.0.pkg` package contains four independently compiled Swiftix Go
commands:

- `memstat` explains the managed-runtime memory model, system budget, actual heap
  bytes, VFS storage bytes, and per-process reported memory;
- `lsof [pid]` lists immutable descriptor snapshots for files, pipes, terminals,
  devices, and UDP/TCP sockets;
- `pstree` renders the current parent/child process hierarchy; and
- `strace pid` prints the target's last 128 completed Swift-native calls.

## Compatibility and honest limits

The package requires Swiftix 0.11.0 or later and teaching procfs schema 1. The
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

## Building and verification

Building requires Swift 6.3 or later and this sibling layout:

```text
swiftixworks/
├── Swiftix/
└── sysutils/
```

Run:

```sh
swift run SysutilsPackageBuilder
swift run SysutilsPackageBuilder --check
swift test -Xswiftc -warnings-as-errors
```

The builder compiles the Go sources to `swiftix/svm64`, installs each image at
`/usr/bin/<command>`, and creates `Artifacts/sysutils_0.1.0.pkg` with the native
Swiftix package codec. `--check` performs a byte-for-byte reproducibility check.

## License

Swiftix sysutils is available under the [MIT License](LICENSE).
