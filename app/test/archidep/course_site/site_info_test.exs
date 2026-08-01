defmodule ArchiDep.CourseSite.SiteInfoTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.SiteInfo

  describe "new/1" do
    test "states what a build was produced from and which edition it is" do
      assert SiteInfo.new(
               version: "1.2.3",
               git_branch: "main",
               git_revision: "abc123",
               years: "2025-2026",
               years_short: "25-26"
             ) ==
               %SiteInfo{
                 version: "1.2.3",
                 git_branch: "main",
                 git_revision: "abc123",
                 years: "2025-2026",
                 years_short: "25-26"
               }
    end

    test "accepts a checkout that can name neither its branch nor its revision" do
      assert SiteInfo.new(version: "1.2.3", years: "2025-2026", years_short: "25-26") ==
               %SiteInfo{
                 version: "1.2.3",
                 git_branch: nil,
                 git_revision: nil,
                 years: "2025-2026",
                 years_short: "25-26"
               }
    end

    test "refuses a version that is not a non-empty string" do
      assert_raise ArgumentError,
                   "version must be a non-empty string, got: nil",
                   fn ->
                     SiteInfo.new(version: nil, years: "2025-2026", years_short: "25-26")
                   end
    end

    test "refuses a branch that is not a non-empty string" do
      assert_raise ArgumentError,
                   "git_branch must be a non-empty string or nil, got: \"\"",
                   fn ->
                     SiteInfo.new(
                       version: "1.2.3",
                       git_branch: "",
                       years: "2025-2026",
                       years_short: "25-26"
                     )
                   end
    end

    test "refuses a revision that is not a non-empty string" do
      assert_raise ArgumentError,
                   "git_revision must be a non-empty string or nil, got: 42",
                   fn ->
                     SiteInfo.new(
                       version: "1.2.3",
                       git_revision: 42,
                       years: "2025-2026",
                       years_short: "25-26"
                     )
                   end
    end

    test "refuses an edition that is not a non-empty string" do
      assert_raise ArgumentError,
                   "years must be a non-empty string, got: \"\"",
                   fn -> SiteInfo.new(version: "1.2.3", years: "", years_short: "25-26") end
    end

    test "refuses a short edition that is not a non-empty string" do
      assert_raise ArgumentError,
                   "years_short must be a non-empty string, got: nil",
                   fn ->
                     SiteInfo.new(version: "1.2.3", years: "2025-2026", years_short: nil)
                   end
    end
  end
end
