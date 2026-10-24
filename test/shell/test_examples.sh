#!/usr/bin/env bash
#
# Tests for `examples/` repositories

set -e

dir="$( cd "${BASH_SOURCE[0]%/*}" && echo "${PWD%/test/shell}" )"
test_source="${dir}/test/shell/${BASH_SOURCE[0]#*test/shell/}"
# shellcheck source=./test_runner.sh
. "${dir}"/test/shell/test_runner.sh
export USE_BAZEL_VERSION=${USE_BAZEL_VERSION:-$(cat $dir/.bazelversion)}

run_in_example_dir(){
  local test_dir="$1";
  shift

  set -e
  cd "examples/${test_dir}"
  "$@"

  # Don't shut down in `scala3` since multiple test cases run there.
  if [[ "$test_dir" != 'scala3' ]]; then
    bazel shutdown
  fi
  cd "$dir"
}

test_scalatest_repositories_example() {
  run_in_example_dir testing/scalatest_repositories bazel test //...
}

test_specs2_junit_repositories_example() {
  run_in_example_dir testing/specs2_junit_repositories bazel test //...
}

test_multi_framework_toolchain_example() {
  run_in_example_dir testing/multi_frameworks_toolchain bazel test //...
}

test_scala3_1_example() {
  run_in_example_dir scala3 bazel build --repo_env=SCALA_VERSION=3.1.3 //...
}

test_scala3_2_example() {
  run_in_example_dir scala3 bazel build --repo_env=SCALA_VERSION=3.2.2 //...
}

test_scala3_3_example() {
  run_in_example_dir scala3 bazel build --repo_env=SCALA_VERSION=3.3.8 //...
}

test_scala3_4_example() {
   run_in_example_dir scala3 bazel build --repo_env=SCALA_VERSION=3.4.3 //...
}

test_scala3_5_example() {
   run_in_example_dir scala3 bazel build --repo_env=SCALA_VERSION=3.5.2 //...
}

test_scala3_6_example() {
   run_in_example_dir scala3 bazel build --repo_env=SCALA_VERSION=3.6.4 //...
}

test_scala3_7_example() {
   run_in_example_dir scala3 bazel build --repo_env=SCALA_VERSION=3.7.4 //...
}

test_scala3_8_example() {
   run_in_example_dir scala3 bazel build --repo_env=SCALA_VERSION=3.8.4 //...
}

test_scala3_9_example() {
   run_in_example_dir scala3 bazel build --repo_env=SCALA_VERSION=3.9.0 //...
}

test_scala3_10_example() {
   run_in_example_dir scala3 bazel build --repo_env=SCALA_VERSION=3.10.0 //...
}

test_semanticdb_example() {
  build_semanticdb_example(){
    bazel build //... --aspects aspect.bzl%semanticdb_info_aspect \
      --output_groups=json_output_file
    echo
    bazel build //...
  }

  run_in_example_dir semanticdb build_semanticdb_example
}

test_cross_build_example() {
  run_cross_build_example() {
    bazel build //...

    local target
    for target in //1_single:bin33 //2_deps:bin213 //2_deps:bin33 \
        //3_select:bin2 //3_select:bin3; do
      bazel run "$target"
    done
  }

  run_in_example_dir crossbuild run_cross_build_example
}

test_overridden_artifacts_example() {
  run_in_example_dir overridden_artifacts bazel test --test_output=errors //...
}

test_twitter_scrooge_example() {
  # Tests for twitter_scrooge toolchain setup problems under Bzlmod from #1744.
  # Neither of the errors occurred under `WORKSPACE`
  build_twitter_scrooge_example() {
    # `ERROR: no such package '@@[unknown repo...`
    bazel build //...
    echo

    # `expected value of type 'string' for dict value element, but got Label`
    bazel build //:justscrooge
  }

  run_in_example_dir twitter_scrooge build_twitter_scrooge_example
}

test_native_example() {
  build_native_example() {
    local mode="${SCALA_NATIVE_TOOLCHAIN_MODE:-host}"
    local flags=("--config=$mode")
    if [[ "$mode" == host ]]; then
      flags+=("--repo_env=CC=${CC:-$(command -v clang)}"
              "--repo_env=CXX=${CXX:-$(command -v clang++)}")
    fi
    bazel build "${flags[@]}" //:greetings
    jar tf bazel-bin/greetings.jar |
      grep -Fxq 'examples/native/Greetings.nir'
    jar tf bazel-bin/greetings.jar |
      grep -Fxq 'scala-native/probe.cpp'

    local output
    output="$(bazel run "${flags[@]}" //:hello_native -- Bazel)"
    [[ "$output" == "Hello, Bazel!" ]]

    bazel test "${flags[@]}" --test_output=errors //:greetings_test
    local status=0
    bazel test "${flags[@]}" --test_arg=--fail //:greetings_test || status=$?
    if [[ "$status" != 3 ]]; then
      echo "expected the native assertion test to fail" >&2
      return 1
    fi
    grep -Fq 'intentional failure' bazel-testlogs/greetings_test/test.log

    # Without explicit registration, hermetic mode must reject the host compiler.
    if output="$(bazel build --@rules_scala//scala_native:toolchain_mode=hermetic //:hello_native 2>&1)"; then
      echo "hermetic mode unexpectedly accepted the host toolchain" >&2
      return 1
    fi
    [[ "$output" == *"Hermetic Scala Native requires"* || "$output" == *"macOS arm64 host mode only"* || "$output" == *"Scala Native requires Clang"* ]]
  }

  run_in_example_dir native build_native_example
}

run_tests "$test_source" "$(get_test_runner "${1:-local}")"
