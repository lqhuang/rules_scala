# Scala Native rules

The Scala Native rule family compiles Scala sources to NIR-containing JARs and
links those JARs into native executables.

## Compatibility

| Component | Supported value |
| --- | --- |
| Scala | 3.8.4 |
| Scala Native | 0.5.12 |
| Java tool runtime | JDK 17 |
| Native compiler | Clang/LLVM 16 or newer through a Bazel C++ toolchain |
| Local verification | macOS arm64, host toolchain |
| Intended Linux target | Linux x86_64, host or hermetic toolchain; real-platform validation pending |
| Presubmit targets | Ubuntu 20.04 (both modes) and macOS (host mode) |
| Verified Bazel version | 7.7.1 |

Other Scala and Scala Native version combinations are not registered.

## Bzlmod configuration

```starlark
bazel_dep(name = "rules_scala", version = "<VERSION>")

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
scala_deps.scala_native()
```

A registered Bazel C++ toolchain must provide Clang, Clang++, platform compile
and link options, sysroot inputs, and runtime libraries. The
[native example](../examples/native/) uses
`toolchains_llvm_bootstrapped` for those inputs.

### Toolchain modes

`--@rules_scala//scala_native:toolchain_mode=hermetic` is the default and
supports Linux x86_64 only. Register the downloaded C++ toolchain explicitly;
the example does this through `--config=hermetic`. Analysis rejects undeclared
compiler paths, missing standard-search suppression flags, and missing declared
LLD. The linker receives an explicit LLD path rather than searching host PATH.
Keep `toolchains_llvm_bootstrapped`'s `empty_sysroot` enabled. Its declared
headers, startup objects, libc, and C++ runtimes are the sysroot equivalent.

`--@rules_scala//scala_native:toolchain_mode=host` explicitly enables the local
C++ toolchain on Linux x86_64 or macOS arm64. Bazel discovers it using its normal
local C++ configuration; use `--repo_env=CC=/absolute/path/to/clang` and
`--repo_env=CXX=/absolute/path/to/clang++` to select it unambiguously. Missing
tools are errors, not a reason to change modes. GCC is not supported.

For hermetic Java compilation and linking, also set
`--java_runtime_version=remotejdk_17` and
`--tool_java_runtime_version=remotejdk_17`, as the example does. Numeric `17`
alone can select a host JDK. These flags do not change JVM users' defaults.
Bazel and the execution operating system remain bootstrap prerequisites.

This is build-input isolation, not a static deployment promise. Linux output
may require a compatible glibc loader and shared libraries. The
[example's Linux review procedure](../examples/native/README.md#linux-review-still-required)
records the pending runtime-baseline and reproducibility checks. Do not claim
a measured minimum glibc version before running those checks.

Load all public rules from one file:

```starlark
load(
    "@rules_scala//scala_native:scala_native.bzl",
    "scala_native_binary",
    "scala_native_library",
    "scala_native_test",
)
```

## `scala_native_library`

```starlark
scala_native_library(
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

Compiles Scala sources with the Scala Native compiler plugin. The output is
`<name>.jar`, containing class files, TASTy, resources, and NIR. Interface JAR
generation defaults to disabled because downstream Native targets require the
full NIR.

The remaining Scala compilation and resource attributes match
[`scala_library`](scala_library.md). Dependencies must contain Native-compatible
NIR. Java source files and JVM-only dependencies are rejected during analysis.

## `scala_native_binary`

```starlark
scala_native_binary(
    name,
    main_class,
    deps,
    copts = [],
    linkopts = [],
    scala_version = "3.8.4",
)
```

| Attribute | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | required | Target name and native executable name. |
| `main_class` | string | required | Fully qualified Scala entry-point class. |
| `deps` | labels | required | Direct `scala_native_library` dependencies. |
| `copts` | strings | `[]` | Extra options appended to both C and C++ compilation commands. |
| `linkopts` | strings | `[]` | Extra options appended to the selected linker options. |
| `scala_version` | string | `3.8.4` | Scala version used for toolchain selection. |

The output is a platform-native executable named `<name>`.

## `scala_native_test`

```starlark
scala_native_test(
    name,
    main_class,
    deps,
    copts = [],
    linkopts = [],
    scala_version = "3.8.4",
)
```

The Native-specific attributes match `scala_native_binary`. The target is a
Bazel test, so the executable passes when it exits with status `0` and fails
for any other status. The entry point can use ordinary Scala assertions; the
[example test](../examples/native/GreetingsTest.scala) demonstrates this form.

## Current limits

- `scala_native_test` runs a user-provided native main; JUnit and other test
  framework adapters are not included.
- Static libraries, dynamic libraries, exported headers, and `CcInfo`
  propagation are not included.
- Prebuilt NIR JAR imports are not included; dependencies must be built with
  `scala_native_library`.
- Native optimization mode, LTO, garbage collector, and build target use Scala
  Native defaults (including Immix GC). Boehm and optional native dependencies
  such as zlib are not provided; APIs requiring them are outside this MVP.
- Arbitrary custom C++ toolchain flag encodings are not yet supported; the
  Linux hermetic integration targets `toolchains_llvm_bootstrapped` 0.3.1 and
  still requires Linux execution validation.
- Cross-compilation and Windows execution are not yet supported.
