load(
    "@rules_scala//scala_js:scala_js.bzl",
    "scala_js_binary",
    "scala_js_library",
    "scala_js_test",
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
