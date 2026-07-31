defmodule ArchiDep.CourseSite.SiteInfoTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.SiteInfo

  describe "new/1" do
    test "states what a build was produced from" do
      assert SiteInfo.new(version: "1.2.3", git_branch: "main", git_revision: "abc123") ==
               %SiteInfo{version: "1.2.3", git_branch: "main", git_revision: "abc123"}
    end

    test "accepts a checkout that can name neither its branch nor its revision" do
      assert SiteInfo.new(version: "1.2.3") ==
               %SiteInfo{version: "1.2.3", git_branch: nil, git_revision: nil}
    end

    test "refuses a version that is not a non-empty string" do
      assert_raise ArgumentError,
                   "Version must be a non-empty string, got: nil",
                   fn -> SiteInfo.new(version: nil) end
    end

    test "refuses a branch that is not a non-empty string" do
      assert_raise ArgumentError,
                   "git_branch must be a non-empty string or nil, got: \"\"",
                   fn -> SiteInfo.new(version: "1.2.3", git_branch: "") end
    end

    test "refuses a revision that is not a non-empty string" do
      assert_raise ArgumentError,
                   "git_revision must be a non-empty string or nil, got: 42",
                   fn -> SiteInfo.new(version: "1.2.3", git_revision: 42) end
    end
  end
end
