"""Public Scala Native library rule."""

load("//scala_native:repositories.bzl", "SCALA_NATIVE_SCALA_VERSION")
load(
    "//scala_native/private/rules:scala_native_library.bzl",
    _scala_native_library = "scala_native_library",
)

def scala_native_library(
        name,
        scala_version = SCALA_NATIVE_SCALA_VERSION,
        **kwargs):
    _scala_native_library(
        name = name,
        scala_version = scala_version,
        **kwargs
    )
