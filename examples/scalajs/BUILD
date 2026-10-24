load("@rules_nodejs//nodejs:toolchain.bzl", "nodejs_toolchain")
load(
    "@rules_scala//scala_js:scala_js.bzl",
    "scala_js_binary",
    "scala_js_library",
    "scala_js_test",
)

nodejs_toolchain(
    name = "host_node",
    node_path = "node",
)

toolchain(
    name = "host_node_macos_arm64",
    target_compatible_with = [
        "@platforms//os:macos",
        "@platforms//cpu:arm64",
    ],
    toolchain = ":host_node",
    toolchain_type = "@rules_nodejs//nodejs:runtime_toolchain_type",
)

toolchain(
    name = "host_node_linux_x86_64",
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    toolchain = ":host_node",
    toolchain_type = "@rules_nodejs//nodejs:runtime_toolchain_type",
)

scala_js_library(
    name = "greetings",
    srcs = ["Greetings.scala"],
)

scala_js_library(
    name = "greetings_api",
    exports = [":greetings"],
)

scala_js_library(
    name = "app",
    srcs = ["HelloScalaJs.scala"],
    deps = [":greetings_api"],
)

# Node is registered by this example's nested MODULE.bazel, so keep run and
# test targets out of outer-workspace wildcard builds.
scala_js_binary(
    name = "hello_scalajs",
    main_class = "examples.scalajs.Main",
    tags = ["manual"],
    deps = [":app"],
)

scala_js_library(
    name = "greetings_test_lib",
    testonly = True,
    srcs = ["GreetingsTest.scala"],
    deps = [":greetings"],
)

scala_js_test(
    name = "greetings_test",
    size = "small",
    main_class = "examples.scalajs.GreetingsTest",
    tags = ["manual"],
    deps = [":greetings_test_lib"],
)
