"""Adds the Scala Native compiler plugin."""

_TOOLCHAIN_TYPE = "//scala_native:toolchain_type"

def phase_native_compile(ctx, _p):
    toolchain = ctx.toolchains[_TOOLCHAIN_TYPE]
    return struct(
        scalacopts = [],
        plugin = [toolchain.nscplugin],
        unused_dependency_checker_ignored_targets = [
            library.label
            for library in toolchain.native_libraries
        ],
    )
