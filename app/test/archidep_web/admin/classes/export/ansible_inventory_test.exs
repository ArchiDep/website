defmodule ArchiDepWeb.Admin.Classes.Export.AnsibleInventoryTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Course.ClassView
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.AnsibleInventory

  test "describe the format" do
    class = ClassView.from(CourseFactory.build(:class, name: "Demo Class"))

    assert {AnsibleInventory.id(), AnsibleInventory.label(), AnsibleInventory.filename(class),
            AnsibleInventory.content_type(), AnsibleInventory.needs_servers?()} ==
             {"ansible-inventory", "Ansible inventory", "Demo Class - inventory.yml",
              "application/yaml; charset=utf-8", true}
  end

  test "include only the students with a server" do
    student = CourseFactory.build(:student_view)

    assert {AnsibleInventory.included?({student, nil}),
            AnsibleInventory.included?({student, ServersFactory.build(:server_view)})} ==
             {false, true}
  end

  test "render a host for the server of each student" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class, name: "ArchiDep 2026")),
      entries: [
        {CourseFactory.build(:student_view, username: "alice"),
         ServersFactory.build(:server_view,
           ip_address: %Postgrex.INET{address: {10, 0, 0, 1}, netmask: 32},
           username: "alice-admin",
           app_username: "archidep",
           ssh_port: nil,
           set_up_at: ~U[2026-11-02 10:00:00.000000Z]
         )},
        {CourseFactory.build(:student_view, username: "bob"),
         ServersFactory.build(:server_view,
           ip_address: %Postgrex.INET{address: {10, 0, 0, 2}, netmask: 32},
           username: "bob",
           app_username: "archidep",
           ssh_port: 22,
           set_up_at: nil
         )},
        {CourseFactory.build(:student_view, username: "carol"),
         ServersFactory.build(:server_view,
           ip_address: %Postgrex.INET{address: {10, 0, 0, 3}, netmask: 32},
           username: "ubuntu",
           app_username: "archidep-carol",
           ssh_port: 2222,
           set_up_at: ~U[2026-11-03 11:00:00.000000Z]
         )}
      ],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    expected = """
    # Ansible inventory of the servers of the ArchiDep students of class ArchiDep 2026, generated 2026-11-18 14:02 UTC
    all:
      children:
        students:
          hosts:
            archidep-st-alice:
              ansible_host: 10.0.0.1
              ansible_user: archidep
            archidep-st-bob:
              ansible_host: 10.0.0.2
              ansible_user: bob
            archidep-st-carol:
              ansible_host: 10.0.0.3
              ansible_user: archidep-carol
              ansible_port: 2222
    """

    assert {AnsibleInventory.render(export, false), AnsibleInventory.render(export, true)} ==
             {expected, expected}
  end

  test "render an empty group without students" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class, name: "Empty")),
      entries: [],
      generated_at: ~U[2026-11-18 09:05:00.000000Z]
    }

    assert AnsibleInventory.render(export, false) == """
           # Ansible inventory of the servers of the ArchiDep students of class Empty, generated 2026-11-18 09:05 UTC
           all:
             children:
               students:
                 hosts: {}
           """
  end
end
