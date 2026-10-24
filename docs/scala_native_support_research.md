# Scala Native support research

Research date: 2026-07-29

## Recommendation

Implement Scala Native as an explicit, native-first rule family:

- `scala_native_library`
- `scala_native_binary`
- `scala_native_test`

Reuse the existing Scala compilation phases, but do not unify the JVM, Scala.js,
and Scala Native public rules yet. The Native MVP should first prove a hermetic
compile, link, test, and package path. Keep shared changes to the small phase
extension seams required by a backend; broader unification can wait until the
Native and Scala.js implementations expose the same concrete duplication.

The initial supported combination should be Scala Native 0.5.12, Scala 3.8.4,
JDK 17, and LLVM/Clang 16 or newer. Scala Native 0.5.12 recommends JDK 17 and
LLVM/Clang 16, and the exact Scala 3.8.4 compiler plugin and native library
artifacts exist in Maven Central
([0.5.12 release](https://github.com/scala-native/scala-native/releases/tag/v0.5.12),
[compiler plugin POM](https://repo1.maven.org/maven2/org/scala-native/nscplugin_3.8.4/0.5.12/nscplugin_3.8.4-0.5.12.pom),
[Scala 3 native library POM](https://repo1.maven.org/maven2/org/scala-native/scala3lib_native0.5_3/3.8.4%2B0.5.12/scala3lib_native0.5_3-3.8.4%2B0.5.12.pom)).
Other combinations should fail during analysis with a clear compatibility
message until they are tested and added to a declared matrix.

## Lessons from previous work

### Issue #1409

[rules_scala issue #1409](https://github.com/bazel-contrib/rules_scala/issues/1409)
correctly identifies the three main integration boundaries:

1. a Scala Native toolchain,
2. Scala compilation that emits NIR, and
3. native linking through Bazel's C/C++ toolchain.

It also favors dedicated `scala_native_*` rules before considering a unified
Scala API. That remains the lowest-risk starting point because Native artifacts,
linking, resources, and execution constraints differ materially from JVM
targets.

### Pull request #1809

[PR #1809](https://github.com/bazel-contrib/rules_scala/pull/1809) proves that
the current phase system can inject the Scala Native compiler plugin, disable
interface jars, propagate NIR-containing jars, and invoke Scala Native's build
API. Its commit history also records useful discoveries: interface jars must be
disabled, and the linker launcher was renamed because it starts a fresh JVM for
each action rather than implementing Bazel's persistent-worker protocol.

The prototype should be treated as design evidence, not as a merge base:

- It is manually demonstrated only for Linux x86-64 and Scala 3.8.1 with Scala
  Native 0.5.10.
- It has no automated Native rule or example tests.
- It passes compiler paths and `CcToolchainInfo.all_files`, but does not derive
  the complete compiler/linker command lines and environments from Bazel's C++
  feature configuration
  ([binary rule](https://github.com/meisam/rules_scala/blob/23c444b6d202735b983fcf85714c01f3bd439ebf/scala_native/private/rules/scala_native_binary.bzl#L27-L143)).
- It hard-codes `-fuse-ld=lld` and calls Scala Native's host-discovery helpers
  ([linker wrapper](https://github.com/meisam/rules_scala/blob/23c444b6d202735b983fcf85714c01f3bd439ebf/scala_native/private/linker/NativeLinker.scala#L109-L145)).
- Its linker writes a work directory beside the declared executable instead of
  making every action output explicit.
- It does not implement `scala_native_test`, C/C++ dependency interop, or
  static/dynamic library providers.

The reusable pieces are the compiler-phase shape, the NIR provider concept, and
the artifact inventory
([library rule](https://github.com/meisam/rules_scala/blob/23c444b6d202735b983fcf85714c01f3bd439ebf/scala_native/private/rules/scala_native_library.bzl#L64-L186),
[toolchain](https://github.com/meisam/rules_scala/blob/23c444b6d202735b983fcf85714c01f3bd439ebf/scala_native/scala_native_toolchain.bzl#L8-L79)).

## Scala Native contracts to preserve

### Compilation and dependency artifacts

The `nscplugin_<full Scala version>` artifact is a JVM compiler plugin. It emits
NIR alongside class files, and published Native libraries package both in a jar
([compiler overview](https://scala-native.org/en/stable/contrib/compiler.html),
[publishing guide](https://scala-native.org/en/stable/user/sbt.html#publishing)).
The runtime libraries use Scala Native's cross-version suffix, such as
`native0.5_3`, rather than the compiler plugin's full Scala suffix
([artifact wiring](https://github.com/scala-native/scala-native/blob/65dd513df188300d0180514ad828308facc5ca61/sbt-scala-native/src/main/scala/scala/scalanative/sbtplugin/ScalaNativePluginInternal.scala#L60-L104),
[cross-version implementation](https://github.com/scala-native/scala-native/blob/65dd513df188300d0180514ad828308facc5ca61/sbt-scala-native/src/main/scala/scala/scalanative/sbtplugin/ScalaNativeCrossVersion.scala#L8-L39)).

Consequences for `scala_native_library`:

- inject the compiler plugin through the existing Scala phase pipeline;
- compile against the Native Scala library and runtime artifacts;
- set `build_ijar = False`, because an interface jar would discard the NIR
  required by downstream Native linking;
- return the full jar as the package artifact;
- propagate an explicit provider containing the transitive NIR jars; and
- preserve Native resources, including `resources/scala-native` sources and
  `scala-native.properties`.

Scala Native discovers C, C++, and assembly sources stored under
`resources/scala-native`, extracts them, and compiles them during the native
build
([native libraries guide](https://scala-native.org/en/stable/user/native.html),
[NativeLib implementation](https://github.com/scala-native/scala-native/blob/65dd513df188300d0180514ad828308facc5ca61/tools/src/main/scala/scala/scalanative/build/NativeLib.scala#L181-L233)).
A resource-preservation test is therefore part of the library rule's contract,
not an optional packaging detail.

### Linking and packaging

Scala Native 0.5.12's tools jar exposes `Build.build` and
`Build.buildCachedAwait`. A build configuration supplies the NIR classpath,
action-private base directory, module name, main class, test mode, compiler
paths, target triple, optimization mode, garbage collector, LTO mode, build
target, and compile/link options
([Build pipeline](https://github.com/scala-native/scala-native/blob/65dd513df188300d0180514ad828308facc5ca61/tools/src/main/scala/scala/scalanative/build/Build.scala#L23-L159),
[Config](https://github.com/scala-native/scala-native/blob/65dd513df188300d0180514ad828308facc5ca61/tools/src/main/scala/scala/scalanative/build/Config.scala#L11-L106)).

The MVP can use a small JVM launcher around this API. It must pass the selected
toolchain configuration explicitly. It must not call `Discover`, which searches
`PATH`, `llvm-config`, environment variables, and host-specific locations such
as `/usr/local`, `/opt/local`, and `/opt/homebrew`
([Discover](https://github.com/scala-native/scala-native/blob/65dd513df188300d0180514ad828308facc5ca61/tools/src/main/scala/scala/scalanative/build/Discover.scala#L44-L123)).

`Build.buildCachedAwait` may be used as an implementation convenience, but
Bazel's action cache remains authoritative. Its working data must stay
action-private and be removed before the action completes. Declare it as a tree
artifact only if it becomes a retained output. A persistent linker worker
should be considered only after profiling shows JVM startup to be material.

The MVP package outputs are:

- a NIR-containing library jar; and
- a native application executable.

Scala Native can also produce static and dynamic libraries
([build-target documentation](https://scala-native.org/en/stable/user/sbt.html#build-target)).
Those targets, exported headers, and `CcInfo` propagation should follow the
application MVP rather than expanding its first acceptance surface.

### Testing

Scala Native test-framework integrations do not run as an ordinary standalone
main. Their native test binary uses `scala.scalanative.testinterface.TestMain`,
receives a server port, and communicates over loopback with a JVM-side runner
([TestMain](https://github.com/scala-native/scala-native/blob/65dd513df188300d0180514ad828308facc5ca61/test-interface/src/main/scala/scala/scalanative/testinterface/TestMain.scala#L61-L93),
[NativeRunnerRPC](https://github.com/scala-native/scala-native/blob/65dd513df188300d0180514ad828308facc5ca61/test-runner/src/main/scala/scala/scalanative/testinterface/NativeRunnerRPC.scala#L14-L45)).
JUnit additionally requires the Native JUnit compiler plugin and runtime
([testing guide](https://scala-native.org/en/stable/user/testing.html),
[JUnit plugin wiring](https://github.com/scala-native/scala-native/blob/65dd513df188300d0180514ad828308facc5ca61/sbt-scala-native/src/main/scala/scala/scalanative/sbtplugin/ScalaNativeJUnitPlugin.scala#L12-L45)).

The smallest useful `scala_native_test` does not need that framework protocol.
It can link a user-provided main containing assertions and use Bazel's process
exit-code contract. A later framework adapter will need the Native test
executable plus a JVM launcher in runfiles that starts the protocol server,
launches the executable, forwards results, and exits with the correct status.
JUnit, automatic discovery, sharding, and filter translation remain a separate
feature.

## Bazel integration requirements

Bazel resolves tools against both execution and target platforms
([platform model](https://bazel.build/extending/platforms),
[toolchain resolution](https://bazel.build/extending/toolchains)). The design
should use two complementary toolchains:

1. a Scala Native toolchain containing the JVM compiler plugin, Native runtime
   and test artifacts, linker launcher, supported versions, and default Native
   settings; and
2. Bazel's selected C++ toolchain for the target compiler, linker, sysroot,
   target triple, flags, environment, and tool files.

The link action should use `cc_common` feature configuration to obtain the
selected tools, command-line fragments, and environment instead of reconstructing
them from paths
([`cc_common`](https://bazel.build/rules/lib/toplevel/cc_common),
[`CcToolchainInfo`](https://bazel.build/rules/lib/providers/CcToolchainInfo)).
Every input, tool, executable, work directory, and output must be declared on
the action; Bazel actions do not inherit the shell environment by default
([actions API](https://bazel.build/rules/lib/builtins/actions)).

A Bazel test rule must return an executable and runfiles, use the standard exit
code contract, and write temporary or undeclared output only in Bazel-provided
test directories
([test encyclopedia](https://bazel.build/reference/test-encyclopedia),
[runfiles](https://bazel.build/extending/rules#runfiles-location)).
The JVM adapter, Native executable, and protocol dependencies must therefore be
assembled in the test target's runfiles rather than discovered from the host.

Cross-compilation is not complete merely because a target triple is accepted.
It is complete only when the selected C++ toolchain provides the target
compiler, sysroot, flags, environment, and link inputs, and when Bazel does not
try to execute a target-incompatible test binary on the execution platform.

## Native-first delivery sequence

1. **N1 — dependency and toolchain contract**
   - Register Scala Native 0.5.12 artifacts for Scala 3.8.4.
   - Add a version compatibility check and a small toolchain analysis test.
   - Keep JDK 17 as the launcher runtime and require a selected C++ toolchain.
2. **N2 — `scala_native_library`**
   - Inject the compiler plugin through the existing phases.
   - Produce a full jar with `.nir`, disable interface jars, and propagate
     transitive NIR jars.
   - Test a two-library dependency graph and preservation of Native resources.
3. **N3 — `scala_native_binary`**
   - Add the JVM build launcher with explicit Native and C++ configuration.
   - Support a debug-mode application on the host platform first.
   - Test `bazel build` and `bazel run`; inspect the action graph to ensure all
     compiler, linker, sysroot, and classpath inputs are declared.
4. **N4 — `scala_native_test`**
   - Link a user-provided assertion main as a Bazel test executable.
   - Demonstrate the exit-code contract under `bazel test`.
   - Add a framework adapter only as a later, independently tested feature.
5. **N5 — documentation and examples**
   - Add a Bzlmod example with a library, executable, test, and Native resource.
   - Document the compatibility matrix, host prerequisites, rule attributes,
     outputs, and known platform limits.
6. **N6 — portability and interop**
   - Add macOS and Windows plus x86-64 and AArch64 coverage.
   - Add release optimization modes, static/dynamic library targets, `CcInfo`
     interop, sanitizers, and cross-compilation only with dedicated tests.

## MVP acceptance gates

The Native MVP is complete when a clean checkout can reproducibly:

- compile two dependent Scala Native libraries and verify that their package
  jars contain NIR;
- build and run a Native executable without reading undeclared host compiler or
  library locations;
- run a native assertion test through `bazel test`;
- rebuild with an action-cache hit and produce the same declared outputs; and
- follow one documented Bzlmod example from setup through build, run, test, and
  package.

Platform support must be documented as the tested matrix, not as an inferred
capability. Broader shared-backend refactoring is deliberately deferred until
the Native and Scala.js implementations demonstrate a stable common seam.
