# Build and test the Scala Native example

This example compiles a Scala Native library, packages its NIR in a JAR, links
a native executable, and runs a native assertion test under Bazel.

## Prerequisites

- Bazelisk or Bazel 7.7.1
- JDK 17
- macOS arm64, Linux amd64, or Linux arm64

The example registers a hermetic LLVM toolchain. Its first build downloads the
Scala, Scala Native, JDK, LLVM, and platform SDK inputs.

## 1. Build the library package

Run these commands from this directory:

```sh
bazel build //:greetings
jar tf bazel-bin/greetings.jar | grep '\.nir$'
```

The second command prints the NIR entries packaged in `greetings.jar`.

## 2. Build and run the native executable

```sh
bazel run //:hello_native -- Bazel
```

Expected output:

```text
Hello, Bazel!
```

## 3. Run the native test

```sh
bazel test //:greetings_test
```

The test target links and executes a native program. An assertion failure or
any other non-zero process exit fails the Bazel test.

## Use the example in another checkout

[`MODULE.bazel`](MODULE.bazel) selects Scala 3.8.4, enables Scala Native 0.5.12,
and registers the C++ toolchain. The `local_path_override` points at this
checkout; remove it and set `rules_scala` to a release containing these rules
when consuming them externally.

[`BUILD`](BUILD) demonstrates `scala_native_library`,
`scala_native_binary`, and `scala_native_test`. See the
[Scala Native rule reference](../../docs/scala_native.md) for their attributes,
outputs, and current compatibility limits.
