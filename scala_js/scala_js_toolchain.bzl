"""Scala.js toolchain definition."""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//scala_js:repositories.bzl", "SCALA_JS_VERSION")

def _scala_js_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            js_libraries = ctx.attr.js_libraries,
            linker_binary = ctx.attr.linker_binary,
            scala_js_version = ctx.attr.scala_js_version,
        ),
    ]

scala_js_toolchain = rule(
    implementation = _scala_js_toolchain_impl,
    doc = "Defines the Scala.js compiler and linker toolchain.",
    attrs = {
        "js_libraries": attr.label_list(
            mandatory = True,
            providers = [JavaInfo],
            doc = "Scala.js standard libraries.",
        ),
        "linker_binary": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
            doc = "JVM executable that invokes the Scala.js linker.",
        ),
        "scala_js_version": attr.string(
            default = SCALA_JS_VERSION,
            doc = "Scala.js version.",
        ),
    },
    provides = [platform_common.ToolchainInfo],
)
