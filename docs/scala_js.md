# Scala.js rules

The Scala.js rule family compiles Scala sources to IR-containing JARs, links
those JARs into JavaScript, and runs JavaScript binaries and tests with a
hermetic Node.js toolchain.

## Compatibility

| Component | Supported value |
| --- | --- |
| Scala | 3.8.4 |
| Scala.js | 1.22.0 |
| Node.js | 22.23.1 in the example |
| Java tool runtime | JDK 17 |
| Verified Bazel version | 7.7.1 |
| MVP platforms | Linux x86_64 and macOS arm64 |

Other Scala and Scala.js version combinations are not registered. Scala 3 uses
its built-in `-scalajs` backend; no compiler plugin is required.

## Bzlmod configuration

```starlark
bazel_dep(name = "rules_scala", version = "<VERSION>")
bazel_dep(name = "rules_nodejs", version = "6.7.5")

node = use_extension("@rules_nodejs//nodejs:extensions.bzl", "node")
node.toolchain(node_version = "22.23.1")
use_repo(node, "nodejs_toolchains")

register_toolchains("@nodejs_toolchains//:all")

scala_config = use_extension(
    "@rules_scala//scala/extensions:config.bzl",
    "scala_config",
)
scala_config.settings(scala_version = "3.8.4")

scala_deps = use_extension(
    "@rules_scala//scala/extensions:deps.bzl",
    "scala_deps",
)
scala_deps.scala()
scala_deps.scala_js()
```

Load all public rules from one file:

```starlark
load(
    "@rules_scala//scala_js:scala_js.bzl",
    "scala_js_binary",
    "scala_js_library",
    "scala_js_test",
)
```

The [standalone example](../examples/scalajs/) contains the complete module and
toolchain configuration.

## Select tool mode

`scala_js_binary` and `scala_js_test` use the string flag
`--@rules_scala//scala_js:toolchain_mode=hermetic` by default.
This requires the selected `rules_nodejs` provider's `node` file and rejects a
host-only `node_path`. The module configuration above downloads Node; it never
falls back to a host executable if download or toolchain resolution fails.
The provider exposes a declared file, not its provenance, so callers registering
custom toolchains are responsible for supplying a hermetic file.

For downloaded Java tools, set both flags in the consuming workspace:

```text
build --java_runtime_version=remotejdk_17
build --tool_java_runtime_version=remotejdk_17
```

For local debugging only, set `--@rules_scala//scala_js:toolchain_mode=host`
and explicitly select a
`rules_nodejs` `nodejs_toolchain(node_path = ...)` runtime toolchain with
`--extra_toolchains`. Host mode rejects a downloaded-file toolchain rather than
silently ignoring the mode. An absolute path is recommended; `node_path = "node"`
explicitly uses `PATH`. Host executables are not included in runfiles and must
exist on the machine running the binary or test.

The example provides `--config=hermetic` (also its default) and `--config=host`.
The latter uses PATH Node and `local_jdk`, with runtime toolchain constraints for
macOS arm64 and Linux x86_64. Use one config per invocation. These settings are
local to the example and do not change pure JVM defaults.

## Compile and package a library

```starlark
scala_js_library(
    name = "greetings",
    srcs = ["Greetings.scala"],
)
```

```sh
bazel build //:greetings
jar tf bazel-bin/greetings.jar | grep '\.sjsir$'
```

The output is `bazel-bin/greetings.jar`. It contains class files, TASTy, and
Scala.js IR. Interface JAR generation is disabled because downstream Scala.js
links require the full `.sjsir` files.

`deps`, `exports`, and `runtime_deps` must provide `ScalaJsInfo`; JVM-only
libraries are rejected during analysis. Java source files are not supported by
this rule.

## Link, package, and run JavaScript

```starlark
scala_js_binary(
    name = "hello",
    main_class = "example.Main",
    deps = [":greetings"],
)
```

```sh
bazel build //:hello
bazel run //:hello
```

The target produces:

- `bazel-bin/hello`, the Bazel launcher; and
- `bazel-bin/hello.js`, the packageable JavaScript file.

The linker emits a single `NoModule` script with the Scala.js optimizer enabled
and source maps disabled. The launcher obtains Node from the registered
`rules_nodejs` runtime toolchain. In the default hermetic mode it includes Node
in runfiles and does not use a host `node` command.

Arguments after `bazel run //:hello --` are forwarded to Node. Scala.js
`ModuleInitializer.mainMethodWithArgs` deliberately invokes the Scala
`main(Array[String])` method with an empty array, so those runtime arguments do
not appear in `main` yet. Node applications that need them can read
`scala.scalajs.js.Dynamic.global.process.argv`, as the example does.

## Run a Scala.js test

```starlark
scala_js_test(
    name = "greetings_test",
    main_class = "example.GreetingsTest",
    deps = [":greetings_test_lib"],
)
```

```sh
bazel test //:greetings_test
```

`scala_js_test` links and executes a user-provided main. A zero exit status
passes; an uncaught assertion or any other non-zero exit status fails the Bazel
test.

## Rule reference

### `scala_js_library`

```starlark
scala_js_library(
    name,
    srcs,
    deps = [],
    exports = [],
    runtime_deps = [],
    resources = [],
    scalacopts = [],
    scala_version = "3.8.4",
)
```

Scala compilation and resource attributes otherwise match
[`scala_library`](scala_library.md).

### `scala_js_binary`

```starlark
scala_js_binary(
    name,
    main_class,
    deps,
    scala_version = "3.8.4",
)
```

### `scala_js_test`

```starlark
scala_js_test(
    name,
    main_class,
    deps,
    scala_version = "3.8.4",
)
```

`scala_js_binary` and `scala_js_test` accept the standard Bazel executable and
test attributes in addition to the attributes shown above.

## Current limits

- `scala_js_test` runs an assertion main; Scala.js test-framework adapters,
  JUnit, discovery, filtering, and sharding are not included.
- Scala 2 compiler plugins are not included.
- ECMAScript modules, CommonJS modules, module splitting, source maps, full
  optimization with Closure Compiler, npm packaging, browser runners, and
  WebAssembly are not included.
- Runtime Node arguments do not populate the Scala `main` argument array.
- Prebuilt Scala.js IR imports are not included; dependencies must be built with
  `scala_js_library`.
- The launcher supports runfiles directories on Linux and macOS. Windows
  manifest-only runfiles are not yet supported.
