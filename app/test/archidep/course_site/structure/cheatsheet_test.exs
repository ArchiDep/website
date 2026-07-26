defmodule ArchiDep.CourseSite.Structure.CheatsheetTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Structure.Cheatsheet

  doctest ArchiDep.CourseSite.Structure.Cheatsheet

  describe "new/3" do
    test "builds a cheatsheet with a shorter name for a list" do
      assert Cheatsheet.new(
               "sysadmin",
               "System Administration Cheatsheet",
               "System Administration"
             ) ==
               %Cheatsheet{
                 slug: "sysadmin",
                 title: "System Administration Cheatsheet",
                 sidebar_title: "System Administration"
               }
    end

    test "builds a cheatsheet that declares no shorter name" do
      assert Cheatsheet.new("docker", "Docker") ==
               %Cheatsheet{slug: "docker", title: "Docker", sidebar_title: nil}
    end
  end
end
