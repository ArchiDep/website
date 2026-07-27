defmodule ArchiDep.CourseSite.MaterialTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Material
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet

  describe "sections/0 and cheatsheets/0" do
    test "list what the compiled course is made of, in reading order" do
      %Structure{sections: sections, cheatsheets: cheatsheets} = Material.structure()

      assert {Material.sections(), Material.cheatsheets()} == {sections, cheatsheets}
    end
  end

  describe "run_virtual_server_exercise/0" do
    test "is the exercise the dashboard sends a student to for their server" do
      assert Material.run_virtual_server_exercise() == %Chapter{
               page: DocumentRef.new(402, "run-virtual-server", :exercise),
               title: "Run your own virtual server on Microsoft Azure",
               slides: nil,
               graded?: false
             }
    end
  end

  describe "sysadmin_cheatsheet/0" do
    test "is the cheatsheet the dashboard sends a student to for a username change" do
      assert Material.sysadmin_cheatsheet() == %Cheatsheet{
               slug: "sysadmin",
               title: "System Administation Cheatsheet",
               sidebar_title: "System Administration"
             }
    end
  end

  describe "__mix_recompile__?/0" do
    test "is answered no by the content directory the module was compiled from" do
      refute Material.__mix_recompile__?()
    end
  end
end
