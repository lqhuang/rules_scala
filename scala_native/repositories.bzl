"""Definitions for Scala Native toolchain artifacts."""

SCALA_NATIVE_VERSION = "0.5.12"
SCALA_NATIVE_SCALA_VERSION = "3.8.4"

def scala_native_artifact_ids(scala_version):
    """Returns Maven artifact IDs for the supported Scala Native matrix."""
    if scala_version != SCALA_NATIVE_SCALA_VERSION:
        return []

    return [
        "org_scala_native_auxlib",
        "org_scala_native_clib",
        "org_scala_native_javalib",
        "org_scala_native_nativelib",
        "org_scala_native_nir",
        "org_scala_native_nscplugin",
        "org_scala_native_posixlib",
        "org_scala_native_scala3lib",
        "org_scala_native_scalalib",
        "org_scala_native_tools",
        "org_scala_native_util",
        "org_scala_native_windowslib",
    ]
