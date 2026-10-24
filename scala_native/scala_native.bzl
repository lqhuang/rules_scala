"""Public Scala Native rules."""

load(
    "//scala_native:scala_native_library.bzl",
    _scala_native_library = "scala_native_library",
)
load(
    "//scala_native/private/rules:scala_native_binary.bzl",
    _scala_native_binary = "scala_native_binary",
    _scala_native_test = "scala_native_test",
)

scala_native_binary = _scala_native_binary
scala_native_library = _scala_native_library
scala_native_test = _scala_native_test
