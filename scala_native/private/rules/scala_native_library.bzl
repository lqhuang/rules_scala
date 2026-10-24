"""Scala Native library compilation."""

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
load("//scala_native:providers.bzl", "ScalaNativeInfo")
load(
    "//scala_native/private/phases:phase_native_compile.bzl",
    "phase_native_compile",
)

_TOOLCHAIN_TYPE = "//scala_native:toolchain_type"

def _phase_collect_jars_native(ctx, p):
    return phase_collect_jars_common(
        ctx,
        p,
        extra_deps = ctx.toolchains[_TOOLCHAIN_TYPE].native_libraries,
    )

def _phase_scala_native_info(ctx, _p):
    transitive_nir_jars = [
        dep[ScalaNativeInfo].transitive_nir_jars
        for dep in ctx.attr.deps + ctx.attr.exports + ctx.attr.runtime_deps
        if ScalaNativeInfo in dep
    ]
    return struct(
        external_providers = {
            "ScalaNativeInfo": ScalaNativeInfo(
                nir_jar = ctx.outputs.jar,
                transitive_nir_jars = depset(
                    direct = [ctx.outputs.jar],
                    transitive = transitive_nir_jars,
                ),
            ),
        },
    )

def _scala_native_library_phases_impl(_ctx):
    return [
        ScalaRulePhase(
            custom_phases = [
                (
                    "replace",
                    "collect_jars",
                    "collect_jars",
                    _phase_collect_jars_native,
                ),
                (
                    "replace",
                    "scala_backend_compiler_inputs",
                    "scala_backend_compiler_inputs",
                    phase_native_compile,
                ),
                (
                    "before",
                    "default_info",
                    "scala_native_info",
                    _phase_scala_native_info,
                ),
            ],
        ),
    ]

scala_native_library_phases = rule(
    implementation = _scala_native_library_phases_impl,
)

_NATIVE_LIBRARY = {
    "attrs": {
        "build_ijar": attr.bool(default = False),
        "deps": attr.label_list(
            aspects = [
                _collect_plus_one_deps_aspect,
            ],
            providers = [ScalaNativeInfo],
        ),
        "exports": attr.label_list(
            allow_files = False,
            providers = [ScalaNativeInfo],
        ),
        "runtime_deps": attr.label_list(providers = [ScalaNativeInfo]),
        "srcs": attr.label_list(allow_files = [
            ".scala",
            ".srcjar",
        ]),
    },
    "phase_providers": [
        "//scala_native/private/rules:scala_native_library_phases",
    ],
    "toolchains": [_TOOLCHAIN_TYPE],
}

scala_native_library = make_scala_library(_NATIVE_LIBRARY)
