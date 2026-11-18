defmodule ArchiDepWeb.Admin.Classes.Export.KnownHostsTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Course.ClassView
  alias ArchiDep.Servers.SSH.SSHHostKey
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.SSHFactory
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.KnownHosts

  test "describe the format" do
    class = ClassView.from(CourseFactory.build(:class, name: "Demo Class"))

    assert {KnownHosts.id(), KnownHosts.label(), KnownHosts.filename(class),
            KnownHosts.content_type(), KnownHosts.needs_servers?()} ==
             {"known-hosts", "Known hosts", "Demo Class - known_hosts.txt",
              "text/plain; charset=utf-8", true}
  end

  test "include only the students with a server" do
    student = CourseFactory.build(:student_view)

    assert {KnownHosts.included?({student, nil}),
            KnownHosts.included?({student, ServersFactory.build(:server_view)})} ==
             {false, true}
  end

  test "render each host key under the hostname and IP address of its server" do
    alice_key = openssh_key(:ed25519)
    bob_ed25519_key = openssh_key(:ed25519)
    bob_ecdsa_key = openssh_key(:ecdsa)

    export = %Export{
      class: ClassView.from(CourseFactory.build(:class, name: "ArchiDep 2026")),
      entries: [
        {CourseFactory.build(:student_view, username: "alice", domain: "archidep1.ch"),
         ServersFactory.build(:server_view,
           ip_address: %Postgrex.INET{address: {10, 0, 0, 1}, netmask: 32},
           ssh_port: nil,
           ssh_host_keys: alice_key
         )},
        {CourseFactory.build(:student_view, username: "bob", domain: "archidep2.ch"),
         ServersFactory.build(:server_view,
           ip_address: %Postgrex.INET{address: {10, 0, 0, 2}, netmask: 32},
           ssh_port: 22,
           ssh_host_keys: "#{bob_ed25519_key}\n#{bob_ecdsa_key}"
         )}
      ],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    expected = """
    # BEGIN SSH host keys of the servers of the ArchiDep students of class ArchiDep 2026, generated 2026-11-18 14:02 UTC
    alice.archidep1.ch,10.0.0.1 #{alice_key}
    bob.archidep2.ch,10.0.0.2 #{bob_ed25519_key}
    bob.archidep2.ch,10.0.0.2 #{bob_ecdsa_key}
    # END SSH host keys of the servers of the ArchiDep students of class ArchiDep 2026
    """

    assert {KnownHosts.render(export, false), KnownHosts.render(export, true)} ==
             {expected, expected}
  end

  test "render the hosts of a server listening on another port than 22 with that port" do
    key = openssh_key(:ed25519)

    export = %Export{
      class: ClassView.from(CourseFactory.build(:class, name: "Ports")),
      entries: [
        {CourseFactory.build(:student_view, username: "carol", domain: "archidep1.ch"),
         ServersFactory.build(:server_view,
           ip_address: %Postgrex.INET{address: {10, 0, 0, 3}, netmask: 32},
           ssh_port: 2222,
           ssh_host_keys: key
         )}
      ],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert KnownHosts.render(export, false) == """
           # BEGIN SSH host keys of the servers of the ArchiDep students of class Ports, generated 2026-11-18 14:02 UTC
           [carol.archidep1.ch]:2222,[10.0.0.3]:2222 #{key}
           # END SSH host keys of the servers of the ArchiDep students of class Ports
           """
  end

  test "render only the comments without students" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class, name: "Empty")),
      entries: [],
      generated_at: ~U[2026-11-18 09:05:00.000000Z]
    }

    assert KnownHosts.render(export, false) == """
           # BEGIN SSH host keys of the servers of the ArchiDep students of class Empty, generated 2026-11-18 09:05 UTC
           # END SSH host keys of the servers of the ArchiDep students of class Empty
           """
  end

  defp openssh_key(type), do: type |> SSHFactory.random_ssh_host_key() |> SSHHostKey.to_openssh()
end
