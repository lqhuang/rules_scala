"""Scala Native executable and test rules."""

load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load(
    "@rules_cc//cc:find_cc_toolchain.bzl",
    "CC_TOOLCHAIN_ATTRS",
    "find_cc_toolchain",
    "use_cc_toolchain",
)
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(
    "//scala:scala_cross_version.bzl",
    "scala_version_transition",
    "toolchain_transition_attr",
)
load("//scala_native:providers.bzl", "ScalaNativeInfo")
load(
    "//scala_native:repositories.bzl",
    "SCALA_NATIVE_SCALA_VERSION",
)

_TOOLCHAIN_TYPE = "//scala_native:toolchain_type"

def _scala_native_executable_impl(ctx):
    native_toolchain = ctx.toolchains[_TOOLCHAIN_TYPE]
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    clang = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
    )
    clang_pp = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_compile,
    )
    compile_variables = cc_common.create_compile_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
    )
    link_variables = cc_common.create_link_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
    )
    toolchain_copts = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
        variables = compile_variables,
    )
    toolchain_cppopts = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_compile,
        variables = compile_variables,
    )
    toolchain_linkopts = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_executable,
        variables = link_variables,
    )
    action_env = dict(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
        variables = compile_variables,
    ))
    action_env.update(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_compile,
        variables = compile_variables,
    ))
    action_env.update(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_executable,
        variables = link_variables,
    ))
    execution_requirements = {}
    for action_name in [
        ACTION_NAMES.c_compile,
        ACTION_NAMES.cpp_compile,
        ACTION_NAMES.cpp_link_executable,
    ]:
        for requirement in cc_common.get_execution_requirements(
            feature_configuration = feature_configuration,
            action_name = action_name,
        ):
            execution_requirements[requirement] = ""

    classpath = depset(
        transitive = [
            library[JavaInfo].transitive_runtime_jars
            for library in native_toolchain.native_libraries
        ] + [
            dep[ScalaNativeInfo].transitive_nir_jars
            for dep in ctx.attr.deps
        ],
    )
    executable = ctx.actions.declare_file(ctx.label.name)
    args = ctx.actions.args()
    args.add("--main", ctx.attr.main_class)
    args.add("--output", executable.path)
    args.add("--work-dir", executable.path + ".native-work")
    args.add("--clang", clang)
    args.add("--clang++", clang_pp)
    args.add_all(classpath, before_each = "--classpath")
    args.add_all(
        toolchain_copts,
        before_each = "--c-option",
    )
    args.add_all(
        toolchain_cppopts,
        before_each = "--cpp-option",
    )
    args.add_all(
        ctx.attr.copts,
        before_each = "--compile-option",
    )
    args.add_all(
        toolchain_linkopts + ctx.attr.linkopts,
        before_each = "--linking-option",
    )

    ctx.actions.run(
        outputs = [executable],
        inputs = depset(
            transitive = [
                classpath,
                cc_toolchain.all_files,
            ],
        ),
        executable = native_toolchain.linker_binary[DefaultInfo].files_to_run,
        arguments = [args],
        env = action_env,
        execution_requirements = execution_requirements,
        mnemonic = "ScalaNativeLink",
        progress_message = "Linking Scala Native executable %{label}",
        toolchain = _TOOLCHAIN_TYPE,
    )

    return [
        DefaultInfo(
            executable = executable,
            files = depset([executable]),
        ),
    ]

_attrs = {
    "copts": attr.string_list(
        doc = "Options passed to clang while compiling generated native code",
    ),
    "deps": attr.label_list(
        providers = [ScalaNativeInfo],
        doc = "Scala Native libraries to link",
    ),
    "linkopts": attr.string_list(
        doc = "Options passed to clang while linking the executable",
    ),
    "main_class": attr.string(mandatory = True),
}
_attrs.update(toolchain_transition_attr)
_attrs.update(CC_TOOLCHAIN_ATTRS)

_scala_native_binary = rule(
    implementation = _scala_native_executable_impl,
    attrs = _attrs,
    executable = True,
    cfg = scala_version_transition,
    fragments = ["cpp"],
    toolchains = [_TOOLCHAIN_TYPE] + use_cc_toolchain(),
)

_scala_native_test = rule(
    implementation = _scala_native_executable_impl,
    attrs = _attrs,
    test = True,
    cfg = scala_version_transition,
    fragments = ["cpp"],
    toolchains = [_TOOLCHAIN_TYPE] + use_cc_toolchain(),
)

def scala_native_binary(
        name,
        scala_version = SCALA_NATIVE_SCALA_VERSION,
        **kwargs):
    _scala_native_binary(
        name = name,
        scala_version = scala_version,
        **kwargs
    )

def scala_native_test(
        name,
        scala_version = SCALA_NATIVE_SCALA_VERSION,
        **kwargs):
    _scala_native_test(
        name = name,
        scala_version = scala_version,
        **kwargs
    )
