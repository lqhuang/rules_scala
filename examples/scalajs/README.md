# Build and test the Scala.js example

This example compiles a Scala.js library, packages its IR in a JAR, links a
JavaScript program, and runs an assertion test with hermetic Node.js.

## Prerequisites

- Bazelisk or Bazel 7.7.1
- JDK 17
- Linux or macOS

The first build downloads Scala, Scala.js, Node.js, and the configured JDK.

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
