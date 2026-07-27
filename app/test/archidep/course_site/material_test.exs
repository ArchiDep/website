defmodule ArchiDep.CourseSite.MaterialTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.HeadingRef
  alias ArchiDep.CourseSite.Material
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter

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

  describe "the headings the dashboard links to" do
    test "are the ones the course material holds" do
      exercise = {:document, DocumentRef.new(402, "run-virtual-server", :exercise)}
      sysadmin = {:cheatsheet, "sysadmin"}

      assert %{
               create_your_server: Material.create_your_server(),
               configure_your_administrator_account:
                 Material.configure_your_administrator_account(),
               give_the_teacher_access: Material.give_the_teacher_access(),
               register_your_server_with_us: Material.register_your_server_with_us(),
               configure_basic_settings: Material.configure_basic_settings(),
               change_the_hostname: Material.change_the_hostname(),
               add_swap_space: Material.add_swap_space(),
               configure_open_ports: Material.configure_open_ports(),
               forgot_to_open_ports: Material.forgot_to_open_ports(),
               change_your_username: Material.change_your_username()
             } == %{
               create_your_server: HeadingRef.new(exercise, "create-your-server"),
               configure_your_administrator_account:
                 HeadingRef.new(exercise, "configure-your-administrator-account"),
               give_the_teacher_access:
                 HeadingRef.new(exercise, "give-the-teacher-access-to-your-virtual-machine"),
               register_your_server_with_us:
                 HeadingRef.new(exercise, "register-your-azure-vm-with-us"),
               configure_basic_settings: HeadingRef.new(exercise, "configure-basic-settings"),
               change_the_hostname:
                 HeadingRef.new(exercise, "change-the-hostname-of-your-virtual-machine"),
               add_swap_space: HeadingRef.new(exercise, "add-swap-space-to-your-virtual-server"),
               configure_open_ports: HeadingRef.new(exercise, "configure-open-ports"),
               forgot_to_open_ports:
                 HeadingRef.new(
                   exercise,
                   "i-forgot-to-open-some-or-all-of-the-ports-in-the-firewall"
                 ),
               change_your_username:
                 HeadingRef.new(sysadmin, "how-do-i-change-my-username-usermod")
             }
    end
  end

  describe "__mix_recompile__?/0" do
    test "is answered no by the content directory the module was compiled from" do
      refute Material.__mix_recompile__?()
    end
  end
end
