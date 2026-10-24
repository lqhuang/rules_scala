load("@bazel_skylib//rules:common_settings.bzl", "string_flag")

package(default_visibility = ["//visibility:public"])

exports_files(["*.bzl"])

string_flag(
    name = "toolchain_mode",
    build_setting_default = "hermetic",
    values = [
        "hermetic",
        "host",
    ],
)

# Scala Native toolchain type
toolchain_type(
    name = "toolchain_type",
    visibility = ["//visibility:public"],
)
