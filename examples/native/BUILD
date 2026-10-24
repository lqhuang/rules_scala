load(
    "@rules_scala//scala_native:scala_native.bzl",
    "scala_native_binary",
    "scala_native_library",
    "scala_native_test",
)

scala_native_library(
    name = "greetings",
    srcs = ["Greetings.scala"],
    resources = ["resources/scala-native/probe.cpp"],
)

scala_native_library(
    name = "greetings_api",
    exports = [":greetings"],
)

scala_native_library(
    name = "app",
    srcs = ["HelloNative.scala"],
    deps = [":greetings_api"],
)

# Native linking needs the C++ toolchain registered by this example's nested
# MODULE.bazel, so keep link and test targets out of outer-workspace wildcards.
scala_native_binary(
    name = "hello_native",
    main_class = "examples.native.Main",
    tags = ["manual"],
    deps = [":app"],
)

scala_native_library(
    name = "greetings_test_lib",
    testonly = True,
    srcs = ["GreetingsTest.scala"],
    deps = [":greetings"],
)

scala_native_test(
    name = "greetings_test",
    size = "small",
    main_class = "examples.native.GreetingsTest",
    tags = ["manual"],
    deps = [":greetings_test_lib"],
)
