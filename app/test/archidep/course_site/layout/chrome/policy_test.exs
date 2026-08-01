defmodule ArchiDep.CourseSite.Layout.Chrome.PolicyTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.Urls.UrlContext

  # What each mode carries is three whole-value examples, which is what the
  # doctests are.
  doctest Policy, import: true

  describe "of/1" do
    test "where a build is mounted says nothing about what its chrome carries" do
      assert Policy.of(urls(mode: :live, base_path: "/website", version: "2026")) ==
               Policy.of(urls(mode: :live))
    end
  end

  defp urls(overrides),
    do: UrlContext.new(Keyword.merge([mode: :live, build_id: "build"], overrides))
end
