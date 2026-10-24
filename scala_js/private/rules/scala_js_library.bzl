"""Scala.js library compilation."""

load("@rules_scala//scala:advanced_usage/providers.bzl", "ScalaRulePhase")
load("@rules_scala//scala:advanced_usage/scala.bzl", "make_scala_library")
load(
    "@rules_scala//scala:plusone.bzl",
    _collect_plus_one_deps_aspect = "collect_plus_one_deps_aspect",
)
load(
    "@rules_scala//scala/private:phases/phase_collect_jars.bzl",
    "phase_collect_jars_common",
)
load("//scala_js:providers.bzl", "ScalaJsInfo")

_TOOLCHAIN_TYPE = "//scala_js:toolchain_type"

def _phase_collect_jars_js(ctx, p):
    return phase_collect_jars_common(
        ctx,
        p,
        extra_deps = ctx.toolchains[_TOOLCHAIN_TYPE].js_libraries,
    )

def _phase_js_compiler_inputs(ctx, _p):
    return struct(
        plugin = [],
        scalacopts = ["-scalajs"],
        unused_dependency_checker_ignored_targets = [
            library.label
            for library in ctx.toolchains[_TOOLCHAIN_TYPE].js_libraries
        ],
    )

def _phase_scala_js_info(ctx, _p):
    transitive_ir_jars = [
        dep[ScalaJsInfo].transitive_ir_jars
        for dep in ctx.attr.deps + ctx.attr.exports + ctx.attr.runtime_deps
        if ScalaJsInfo in dep
    ]
    return struct(
        external_providers = {
            "ScalaJsInfo": ScalaJsInfo(
                ir_jar = ctx.outputs.jar,
                transitive_ir_jars = depset(
                    direct = [ctx.outputs.jar],
                    transitive = transitive_ir_jars,
                ),
            ),
        },
    )

def _scala_js_library_phases_impl(_ctx):
    return [
        ScalaRulePhase(
            custom_phases = [
                (
                    "replace",
                    "collect_jars",
                    "collect_jars",
                    _phase_collect_jars_js,
                ),
                (
                    "replace",
                    "scala_backend_compiler_inputs",
                    "scala_backend_compiler_inputs",
                    _phase_js_compiler_inputs,
                ),
                (
                    "before",
                    "default_info",
                    "scala_js_info",
                    _phase_scala_js_info,
                ),
            ],
        ),
    ]

scala_js_library_phases = rule(
    implementation = _scala_js_library_phases_impl,
)

_JS_LIBRARY = {
    "attrs": {
        "build_ijar": attr.bool(default = False),
        "deps": attr.label_list(
            aspects = [
                _collect_plus_one_deps_aspect,
            ],
            providers = [ScalaJsInfo],
        ),
        "exports": attr.label_list(
            allow_files = False,
            providers = [ScalaJsInfo],
        ),
        "runtime_deps": attr.label_list(providers = [ScalaJsInfo]),
        "srcs": attr.label_list(allow_files = [
            ".scala",
            ".srcjar",
        ]),
    },
    "phase_providers": [
        "//scala_js/private/rules:scala_js_library_phases",
    ],
    "toolchains": [_TOOLCHAIN_TYPE],
}

scala_js_library = make_scala_library(_JS_LIBRARY)
