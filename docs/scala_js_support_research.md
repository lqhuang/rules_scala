# Scala.js support research

Research date: 2026-07-29

## Recommendation

Start with dedicated `scala_js_library`, `scala_js_binary`, and
`scala_js_test` rules for Scala 3.8.4 and Scala.js 1.22.0. Reuse the existing
Scala compilation phases, preserve full IR jars, link in a separate Bazel
action, and execute through a pinned Node toolchain.

This is the smallest complete compile, package, run, and test path. A shared
public rule across JVM, Scala.js, and Scala Native should wait until both
backend implementations expose proven common behavior.

## Lessons from the previous Native work

[Issue #1409](https://github.com/bazel-contrib/rules_scala/issues/1409) and
[PR #1809](https://github.com/bazel-contrib/rules_scala/pull/1809) identify an
architecture that transfers cleanly to Scala.js:

1. inject backend-specific compiler inputs through a toolchain;
2. preserve the backend IR in normal library jars;
3. propagate an explicit backend provider through dependencies; and
4. perform platform linking as a separate action.

The Native journey also exposed the risks of interface jars, host discovery,
undeclared linker inputs, and demonstrations without automated run/test
coverage. The Scala.js implementation therefore disables interface jars,
declares the entire linker classpath, uses a hermetic runtime toolchain, and
tests the linked output and process exit status.

The platforms differ at the final stage: Native consumes Bazel's C++ toolchain,
while Scala.js consumes the JVM linker API and a Node runtime. That difference
supports sharing compiler phase seams without prematurely unifying the public
rules.

## Compiler and library contract

Scala 3 embeds its Scala.js backend. The compiler option is `-scalajs`, and the
backend emits `.sjsir` files alongside class files and TASTy. The Scala 3.8.4
compiler sources describe the option as requiring `scalajs-library.jar` and
enable `GenSJSIR` only in Scala.js mode
([Scala settings](https://github.com/scala/scala3/blob/3.8.4/compiler/src/dotty/tools/dotc/config/ScalaSettings.scala),
[GenSJSIR](https://github.com/scala/scala3/blob/3.8.4/compiler/src/dotty/tools/backend/sjs/GenSJSIR.scala)).
There is no Scala 3 `scalajs-compiler` plugin artifact.

Scala 3.8.4 emits Scala.js IR version 1.20. Scala.js 1.x IR is backward
compatible within the major version, so the 1.22.0 linker accepts that output
([IR version policy](https://www.scala-js.org/doc/internals/compile-opt-pipeline.html)).

The resolved runtime roots are:

- `org.scala-js:scalajs-library_2.13:1.22.0`;
- `org.scala-js:scalajs-scalalib_2.13:3.8.4`;
- `org.scala-js:scalajs-javalib:1.22.0`; and
- `org.scala-js:scalajs-javalib-intf:1.22.0` for compile-time interfaces.

`org.scala-lang:scala3-library_sjs1_3:3.8.4` is only a 312-byte Maven
aggregator that points to `scalajs-scalalib_2.13:3.8.4`; the toolchain can
depend on the actual library directly. The ordinary Scala 3 library remains on
the compiler classpath for class and TASTy definitions, while the Scala.js jars
provide the linkable IR.

Consequences for `scala_js_library`:

- add `-scalajs` through the backend compiler-input phase;
- add the Scala.js libraries to compilation and runtime classpaths;
- set `build_ijar = False`;
- package `.class`, `.tasty`, `.sjsir`, and resources in the full output jar;
- propagate transitive IR jars in `ScalaJsInfo`; and
- require `ScalaJsInfo` on dependency attributes so JVM dependencies fail
  during analysis instead of deep in the linker.

## Linker and runtime contract

Scala.js 1.22.0 exposes a directory-oriented linker API. The required pipeline
is:

1. `PathIRContainer.fromClasspath`;
2. `StandardImpl.irFileCache().newCache`;
3. `StandardImpl.linker(StandardConfig(...))`;
4. `ModuleInitializer.mainMethodWithArgs`; and
5. `PathOutputDirectory`.

See the official [linker implementation](https://github.com/scala-js/scala-js/blob/v1.22.0/linker/shared/src/main/scala/org/scalajs/linker/StandardImpl.scala),
[classpath reader](https://github.com/scala-js/scala-js/blob/v1.22.0/linker/jvm/src/main/scala/org/scalajs/linker/PathIRContainer.scala),
and [output directory](https://github.com/scala-js/scala-js/blob/v1.22.0/linker/jvm/src/main/scala/org/scalajs/linker/PathOutputDirectory.scala).

The MVP uses the default `NoModule`, `FewestModules`, and parallel-linking
configuration, enables the Scala.js optimizer, disables source maps, and links
in an action-private directory before moving `main.js` to the declared Bazel
output. Closure Compiler is present in the linker's published graph but remains
disabled by the standard configuration.

The executable and test launchers resolve Node from
[`rules_nodejs`](https://registry.bazel.build/modules/rules_nodejs) 6.7.5.
No host Node, npm installation, `package.json`, or npm dependency graph is
needed for a `NoModule` script.

`ModuleInitializer.mainMethodWithArgs` passes a link-time literal array; its
two-argument overload passes an empty array
([initializer contract](https://github.com/scala-js/scala-js/blob/v1.22.0/linker-interface/shared/src/main/scala/org/scalajs/linker/interface/ModuleInitializer.scala#L66-L99)).
Forwarding runtime Node arguments into Scala `main` needs a separate bootstrap
design and is explicitly outside the MVP.

## Testing and packaging

The smallest useful test target links a user main containing assertions and
uses Bazel's standard process exit contract. This verifies compilation,
transitive IR propagation, linking, runfiles, Node selection, and failure
reporting without implementing the Scala.js sbt test adapter protocol.

The declared package artifacts are:

- `<name>.jar` for a Scala.js library; and
- `<name>.js` for a linked binary or test.

The executable launcher is also declared for `bazel run` and `bazel test`.
Framework discovery, browser execution, npm packaging, source maps, module
variants, WebAssembly, and full optimization should each be added only with a
focused integration test.

## Acceptance gates

The Scala.js MVP is complete when a clean checkout can:

- compile a library jar and verify a stable `.sjsir` entry;
- propagate IR through an exported dependency;
- link a non-empty, declared JavaScript artifact;
- run it with a pinned Node toolchain;
- pass and intentionally fail an assertion-based Bazel test; and
- follow one standalone Bzlmod example for compile, package, run, and test.
