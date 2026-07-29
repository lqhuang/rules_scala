"""Definitions for Scala.js toolchain artifacts."""

SCALA_JS_VERSION = "1.22.0"
SCALA_JS_SCALA_VERSION = "3.8.4"

def scala_js_artifact_ids(scala_version):
    """Returns Maven artifact IDs for the supported Scala.js matrix."""
    if scala_version != SCALA_JS_SCALA_VERSION:
        return []

    return [
        "com_google_javascript_closure_compiler",
        "org_scala_js_scalajs_ir",
        "org_scala_js_scalajs_javalib",
        "org_scala_js_scalajs_javalib_intf",
        "org_scala_js_scalajs_library",
        "org_scala_js_scalajs_linker",
        "org_scala_js_scalajs_linker_interface",
        "org_scala_js_scalajs_logging",
        "org_scala_js_scalajs_scalalib",
        "org_scala_lang_modules_scala_parallel_collections_3",
    ]
