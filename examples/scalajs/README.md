# Build and test the Scala.js example

This example compiles a Scala.js library, packages its IR in a JAR, links a
JavaScript program, and runs an assertion test with hermetic Node.js.

## Prerequisites

- Bazelisk or Bazel 7.7.1
- Linux x86_64 or macOS arm64
- A JDK's `jar` command for the optional JAR inspection below

The first build downloads Scala, Scala.js, Node.js, and JDK 17. Both Java runtime
flags are pinned to `remotejdk_17` in this example, without changing JVM defaults
elsewhere in the checkout. A failed download does not fall back to host tools.

## Select hermetic or host tools

Hermetic mode is the default. To request it explicitly:

```sh
bazel run --config=hermetic //:hello_scalajs -- Bazel
bazel test --config=hermetic //:greetings_test
```

For local debugging with Node on `PATH` and a local JDK 17 or 21 selected by
`JAVA_HOME`:

```sh
bazel run --config=host //:hello_scalajs -- Bazel
bazel test --config=host --test_env=PATH //:greetings_test
```

Host mode explicitly selects a `rules_nodejs` `node_path` toolchain and
`local_jdk`. It is not reproducible and requires those tools on the execution
machine. The example constrains host Node to macOS arm64 and Linux x86_64.
Use only one config per invocation. Selecting host Node without host mode, or
host mode without a host Node toolchain, fails during analysis.

## Build the library package

Run from this directory:

```sh
bazel build //:greetings
jar tf bazel-bin/greetings.jar | grep '\.sjsir$'
```

## Link and run the JavaScript application

```sh
bazel build //:hello_scalajs
bazel run //:hello_scalajs -- Bazel
```

Expected output:

```text
Hello, Bazel!
```

The packageable script is `bazel-bin/hello_scalajs.js`.

## Run the Scala.js test

```sh
bazel test //:greetings_test
```

An uncaught assertion or another non-zero Node exit fails the Bazel test.

## Use the example in another checkout

[`MODULE.bazel`](MODULE.bazel) selects Scala 3.8.4, enables Scala.js 1.22.0,
and registers Node.js 22.23.1. Its `local_path_override` points at this
checkout; remove that override and select a `rules_scala` release containing
these rules when consuming them externally.

[`BUILD`](BUILD) demonstrates `scala_js_library`, `scala_js_binary`, exported
dependency propagation, and `scala_js_test`. See the
[Scala.js rule guide and reference](../../docs/scala_js.md) for outputs,
attributes, and current limits.
