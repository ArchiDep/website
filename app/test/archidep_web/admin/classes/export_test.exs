defmodule ArchiDepWeb.Admin.Classes.ExportTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Course.ClassView
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.AnsibleInventory
  alias ArchiDepWeb.Admin.Classes.Export.Csv
  alias ArchiDepWeb.Admin.Classes.Export.DnsRecords
  alias ArchiDepWeb.Admin.Classes.Export.Emails
  alias ArchiDepWeb.Admin.Classes.Export.KnownHosts
  alias ArchiDepWeb.Admin.Classes.Export.SshConfig
  alias ArchiDepWeb.Admin.Classes.Export.SshExerciseInventory

  test "list the formats in the order of the export dialog" do
    assert Export.formats() == [
             Emails,
             Csv,
             SshExerciseInventory,
             KnownHosts,
             SshConfig,
             AnsibleInventory,
             DnsRecords
           ]
  end

  test "find a format by its identifier" do
    assert Enum.map(
             [
               "emails",
               "csv",
               "ssh-exercise-inventory",
               "known-hosts",
               "ssh-config",
               "ansible-inventory",
               "dns-records",
               "unknown"
             ],
             &Export.fetch_format/1
           ) == [
             {:ok, Emails},
             {:ok, Csv},
             {:ok, SshExerciseInventory},
             {:ok, KnownHosts},
             {:ok, SshConfig},
             {:ok, AnsibleInventory},
             {:ok, DnsRecords},
             {:error, :format_not_found}
           ]
  end

  test "pair each student with their server, in the order of the students" do
    class = ClassView.from(CourseFactory.build(:class))
    alice = CourseFactory.build(:student_view)
    bob = CourseFactory.build(:student_view)
    carol = CourseFactory.build(:student_view)
    alice_server = server_of(alice)
    carol_server = server_of(carol)
    now = ~U[2026-11-18 14:02:17.000000Z]

    assert Export.new(class, [alice, bob, carol], [carol_server, alice_server], now) ==
             %Export{
               class: class,
               entries: [{alice, alice_server}, {bob, nil}, {carol, carol_server}],
               generated_at: now
             }
  end

  test "list the students a format excludes" do
    alice = CourseFactory.build(:student_view)
    bob = CourseFactory.build(:student_view)
    carol = CourseFactory.build(:student_view)

    export = %Export{
      class: ClassView.from(CourseFactory.build(:class)),
      entries: [{alice, nil}, {bob, server_of(bob)}, {carol, nil}],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert {Export.excluded_students(export, Emails), Export.excluded_students(export, SshConfig)} ==
             {[], [alice, carol]}
  end

  test "render a format with only the students it includes" do
    alice = CourseFactory.build(:student_view, username: "alice")
    bob = CourseFactory.build(:student_view, username: "bob")

    bob_server =
      ServersFactory.build(:server_view,
        ip_address: %Postgrex.INET{address: {10, 0, 0, 2}, netmask: 32},
        username: "bob",
        ssh_port: nil,
        set_up_at: nil,
        owner: ServersFactory.build(:server_owner, root: false, group_member_id: bob.id)
      )

    export = %Export{
      class: ClassView.from(CourseFactory.build(:class, name: "Partial")),
      entries: [{alice, nil}, {bob, bob_server}],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert Export.render(export, SshConfig, false) == """
           # BEGIN SSH host aliases of the servers of the ArchiDep students of class Partial, generated 2026-11-18 14:02 UTC
           Host archidep-st-bob
             HostName 10.0.0.2
             User bob
           # END SSH host aliases of the servers of the ArchiDep students of class Partial
           """
  end

  defp server_of(student),
    do:
      ServersFactory.build(:server_view,
        owner: ServersFactory.build(:server_owner, root: false, group_member_id: student.id)
      )
end
