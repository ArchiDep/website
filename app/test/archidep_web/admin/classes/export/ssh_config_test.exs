defmodule ArchiDepWeb.Admin.Classes.Export.SshConfigTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Course.ClassView
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.SshConfig

  test "describe the format" do
    class = ClassView.from(CourseFactory.build(:class, name: "Demo Class"))

    assert {SshConfig.id(), SshConfig.label(), SshConfig.filename(class),
            SshConfig.content_type(), SshConfig.needs_servers?()} ==
             {"ssh-config", "SSH config", "Demo Class - ssh_config.txt",
              "text/plain; charset=utf-8", true}
  end

  test "include only the students with a server" do
    student = CourseFactory.build(:student_view)

    assert {SshConfig.included?({student, nil}),
            SshConfig.included?({student, ServersFactory.build(:server_view)})} ==
             {false, true}
  end

  test "render a host alias for the server of each student" do
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
    # BEGIN SSH host aliases of the servers of the ArchiDep students of class ArchiDep 2026, generated 2026-11-18 14:02 UTC
    Host archidep-st-alice
      HostName 10.0.0.1
      User archidep

    Host archidep-st-bob
      HostName 10.0.0.2
      User bob

    Host archidep-st-carol
      HostName 10.0.0.3
      User archidep-carol
      Port 2222
    # END SSH host aliases of the servers of the ArchiDep students of class ArchiDep 2026
    """

    assert {SshConfig.render(export, false), SshConfig.render(export, true)} ==
             {expected, expected}
  end

  test "render only the comments without students" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class, name: "Empty")),
      entries: [],
      generated_at: ~U[2026-11-18 09:05:00.000000Z]
    }

    assert SshConfig.render(export, false) == """
           # BEGIN SSH host aliases of the servers of the ArchiDep students of class Empty, generated 2026-11-18 09:05 UTC
           # END SSH host aliases of the servers of the ArchiDep students of class Empty
           """
  end
end
