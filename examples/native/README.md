# Build and test the Scala Native example

This example compiles a Scala Native library, packages its NIR in a JAR, links
a native executable, and runs a native assertion test under Bazel.

## Prerequisites

- Bazelisk or Bazel 7.7.1
- JDK 17
- macOS arm64 or Linux x86_64

Choose one toolchain mode for every command below:

- `--config=host`: use the local Bazel C++ toolchain. Install Clang/LLVM 16+
  and the platform SDK/development libraries. Set
  `--repo_env=CC=/absolute/path/to/clang` and
  `--repo_env=CXX=/absolute/path/to/clang++` to avoid ambiguous discovery.
  On macOS, Xcode's `/usr/bin/clang` and `/usr/bin/clang++` work with the
  active SDK selected by `xcode-select`.
- `--config=hermetic`: Linux x86_64 only. Download the pinned
  `toolchains_llvm_bootstrapped` 0.3.1 compiler and build its declared headers,
  startup objects, and runtime libraries. This is the sysroot equivalent;
  no host SDK or library fallback is allowed. The first build is expensive.

Both modes use a downloaded JDK 17. Host mode is for debugging, not a
reproducibility guarantee. No mode silently retries with a different compiler.
The commands below use host mode; on Linux substitute `hermetic` to exercise
the isolated toolchain.

## 1. Build the library package

Run these commands from this directory:

```sh
bazel build --config=host //:greetings
jar tf bazel-bin/greetings.jar | grep '\.nir$'
```

The second command prints the NIR entries packaged in `greetings.jar`.

## 2. Build and run the native executable

```sh
bazel run --config=host //:hello_native -- Bazel
```

Expected output:

```text
Hello, Bazel!
```

## 3. Run the native test

```sh
bazel test --config=host //:greetings_test
```

The test target links and executes a native program. An assertion failure or
any other non-zero process exit fails the Bazel test.

## Use the example in another checkout

[`MODULE.bazel`](MODULE.bazel) selects Scala 3.8.4 and enables Scala Native 0.5.12.
[`.bazelrc`](.bazelrc) selects the C++ toolchain explicitly by mode.
The `local_path_override` points at this
checkout; remove it and set `rules_scala` to a release containing these rules
when consuming them externally.

[`BUILD`](BUILD) demonstrates `scala_native_library`,
`scala_native_binary`, and `scala_native_test`. See the
[Scala Native rule reference](../../docs/scala_native.md) for their attributes,
outputs, and current compatibility limits.

## Linux review still required

The Linux hermetic configuration has not been executed on the macOS development
machine. Run both modes on Linux before treating either Linux lane as verified:

```sh
SCALA_NATIVE_TOOLCHAIN_MODE=host RULES_SCALA_TEST_ONLY=test_native_example ./test_examples.sh
SCALA_NATIVE_TOOLCHAIN_MODE=hermetic RULES_SCALA_TEST_ONLY=test_native_example ./test_examples.sh
```

Run these two commands from the repository root. They check NIR/resource
packaging, exported dependencies, executable output, passing tests, intentional
assertion failures, and rejection of implicit host fallback.

In the example directory, inspect `readelf -l bazel-bin/hello_native`,
`readelf -d bazel-bin/hello_native`, and
`readelf --version-info bazel-bin/hello_native` to record the ELF interpreter,
shared libraries, and required glibc symbol versions. The toolchain documents
a default glibc baseline of 2.28 in most cases; this is not yet a measured
minimum for this executable. The executable is not promised to run on musl.
Compare artifacts from two separate Bazel output bases before claiming
byte-for-byte reproducibility; declared tool inputs alone do not prove it.
