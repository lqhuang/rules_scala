"""Public Scala.js rules."""

load("//scala_js:repositories.bzl", "SCALA_JS_SCALA_VERSION")
load(
    "//scala_js/private/rules:scala_js_binary.bzl",
    _scala_js_binary = "scala_js_binary",
    _scala_js_test = "scala_js_test",
)
load(
    "//scala_js/private/rules:scala_js_library.bzl",
    _scala_js_library = "scala_js_library",
)

scala_js_binary = _scala_js_binary
scala_js_test = _scala_js_test

def scala_js_library(
        name,
        scala_version = SCALA_JS_SCALA_VERSION,
        **kwargs):
    _scala_js_library(
        name = name,
        scala_version = scala_version,
        **kwargs
    )
