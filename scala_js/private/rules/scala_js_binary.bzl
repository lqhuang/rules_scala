"""Scala.js executable and test rules."""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(
    "//scala:scala_cross_version.bzl",
    "scala_version_transition",
    "toolchain_transition_attr",
)
load("//scala_js:providers.bzl", "ScalaJsInfo")
load("//scala_js:repositories.bzl", "SCALA_JS_SCALA_VERSION")

_NODE_TOOLCHAIN_TYPE = "@rules_nodejs//nodejs:runtime_toolchain_type"
_SCALA_JS_TOOLCHAIN_TYPE = "//scala_js:toolchain_type"

def _scala_js_executable_impl(ctx):
    js_toolchain = ctx.toolchains[_SCALA_JS_TOOLCHAIN_TYPE]
    node = ctx.toolchains[_NODE_TOOLCHAIN_TYPE].nodeinfo
    classpath = depset(
        transitive = [
            library[JavaInfo].transitive_runtime_jars
            for library in js_toolchain.js_libraries
        ] + [
            dep[ScalaJsInfo].transitive_ir_jars
            for dep in ctx.attr.deps
        ],
    )
    javascript = ctx.actions.declare_file(ctx.label.name + ".js")
    args = ctx.actions.args()
    args.add("--main", ctx.attr.main_class)
    args.add("--output", javascript.path)
    args.add("--work-dir", javascript.path + ".link")
    args.add_all(classpath, before_each = "--classpath")

    ctx.actions.run(
        outputs = [javascript],
        inputs = classpath,
        executable = js_toolchain.linker_binary[DefaultInfo].files_to_run,
        arguments = [args],
        mnemonic = "ScalaJsLink",
        progress_message = "Linking Scala.js executable %{label}",
        toolchain = _SCALA_JS_TOOLCHAIN_TYPE,
    )

    launcher = ctx.actions.declare_file(ctx.label.name)
    javascript_runfile = ctx.workspace_name + "/" + javascript.short_path
    runfiles_files = [javascript]
    if node.node:
        node_runfile = node.node.short_path
        if node_runfile.startswith("../"):
            node_runfile = node_runfile[3:]
        else:
            node_runfile = ctx.workspace_name + "/" + node_runfile
        node_path = "$runfiles_dir/" + node_runfile
        runfiles_files.append(node.node)
    else:
        node_path = node.node_path
    ctx.actions.write(
        launcher,
        "\n".join([
            "#!/bin/sh",
            "set -eu",
            "runfiles_dir=\"${RUNFILES_DIR:-${TEST_SRCDIR:-$0.runfiles}}\"",
            "exec \"%s\" \"$runfiles_dir/%s\" \"$@\"" % (
                node_path,
                javascript_runfile,
            ),
            "",
        ]),
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = launcher,
            files = depset([launcher, javascript]),
            runfiles = ctx.runfiles(files = runfiles_files),
        ),
    ]

_attrs = {
    "deps": attr.label_list(
        providers = [ScalaJsInfo],
        doc = "Scala.js libraries to link.",
    ),
    "main_class": attr.string(mandatory = True),
}
_attrs.update(toolchain_transition_attr)

_scala_js_binary = rule(
    implementation = _scala_js_executable_impl,
    attrs = _attrs,
    executable = True,
    cfg = scala_version_transition,
    toolchains = [
        _NODE_TOOLCHAIN_TYPE,
        _SCALA_JS_TOOLCHAIN_TYPE,
    ],
)

_scala_js_test = rule(
    implementation = _scala_js_executable_impl,
    attrs = _attrs,
    test = True,
    cfg = scala_version_transition,
    toolchains = [
        _NODE_TOOLCHAIN_TYPE,
        _SCALA_JS_TOOLCHAIN_TYPE,
    ],
)

def scala_js_binary(
        name,
        scala_version = SCALA_JS_SCALA_VERSION,
        **kwargs):
    _scala_js_binary(
        name = name,
        scala_version = scala_version,
        **kwargs
    )

def scala_js_test(
        name,
        scala_version = SCALA_JS_SCALA_VERSION,
        **kwargs):
    _scala_js_test(
        name = name,
        scala_version = scala_version,
        **kwargs
    )
