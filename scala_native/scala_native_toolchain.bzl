"""Scala Native toolchain definition for Bazel."""

load("@rules_java//java:defs.bzl", "JavaInfo")
load("//scala_native:repositories.bzl", "SCALA_NATIVE_VERSION")

def _scala_native_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            linker_binary = ctx.attr.linker_binary,
            native_libraries = ctx.attr.native_libraries,
            nscplugin = ctx.attr.nscplugin,
            scala_native_version = ctx.attr.scala_native_version,
        ),
    ]

scala_native_toolchain = rule(
    implementation = _scala_native_toolchain_impl,
    doc = "Defines the Scala Native compiler and linker toolchain.",
    attrs = {
        "linker_binary": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
            doc = "JVM executable that invokes the Scala Native linker",
        ),
        "native_libraries": attr.label_list(
            mandatory = True,
            providers = [JavaInfo],
            doc = "Scala Native standard libraries",
        ),
        "nscplugin": attr.label(
            mandatory = True,
            providers = [JavaInfo],
            doc = "Scala Native compiler plugin",
        ),
        "scala_native_version": attr.string(
            default = SCALA_NATIVE_VERSION,
            doc = "Scala Native version",
        ),
    },
    provides = [platform_common.ToolchainInfo],
)
