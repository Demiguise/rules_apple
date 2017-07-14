# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Support functions for working with Swift."""

load(
    "@build_bazel_rules_apple//apple/bundling:apple_bundling_aspect.bzl",
    "apple_bundling_aspect",
)
load(
    "@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:provider_support.bzl",
    "provider_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundlingSwiftInfo",
)
load(
    "@build_bazel_rules_apple//apple:swift.bzl",
    "swift_linkopts",
)


def _uses_swift(ctx):
  """Returns True if the current target uses Swift.

  Note that this is not propagated through extensions or child apps (such as
  Watch) -- that is, an Objective-C application that contains a Swift
  application extension does not "use Swift" in the sense denoted by this
  function.

  Args:
    ctx: The Skylark context.
  Returns:
    True if the current target directly uses Swift; otherwise, False.
  """
  swift_provider = binary_support.get_binary_provider(
      ctx, AppleBundlingSwiftInfo)
  return swift_provider.uses_swift


def _swift_runtime_linkopts_impl(ctx):
  """Implementation of the internal `swift_runtime_linkopts` rule.

  This rule is an internal implementation detail and should not be used directly
  by clients. It examines the dependencies of the target to determine if Swift
  was used and, if so, propagates additional linker options to have the runtime
  either dynamically or statically linked.

  Args:
    ctx: The rule context.
  Returns:
    A `struct` containing the `objc` provider that should be propagated to a
    binary to dynamically or statically link the Swift runtime.
  """
  if _uses_swift(ctx):
    is_static = ctx.attr.is_static
    linkopts = swift_linkopts(ctx.fragments.apple, ctx.var, is_static=is_static)
    if is_static:
      linkopts.extend(["-Xlinker", "-force_load_swift_libs"])

    return struct(
        objc=apple_common.new_objc_provider(
            linkopt=depset(linkopts, order="topological"),
        ))
  else:
    return struct(objc=apple_common.new_objc_provider())


swift_runtime_linkopts = rule(
    _swift_runtime_linkopts_impl,
    attrs={
        "is_static": attr.bool(),
        "deps": attr.label_list(
            aspects=[apple_bundling_aspect],
            mandatory=True,
        ),
    },
    fragments=["apple", "objc"],
)


# Define the loadable module that lists the exported symbols in this file.
swift_support = struct(
    uses_swift=_uses_swift,
)
