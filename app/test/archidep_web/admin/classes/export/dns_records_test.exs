defmodule ArchiDepWeb.Admin.Classes.Export.DnsRecordsTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Course.ClassView
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.DnsRecords

  test "describe the format" do
    class = ClassView.from(CourseFactory.build(:class, name: "Demo Class"))

    assert {DnsRecords.id(), DnsRecords.label(), DnsRecords.filename(class),
            DnsRecords.content_type(), DnsRecords.needs_servers?()} ==
             {"dns-records", "DNS records", "Demo Class - DNS records.txt",
              "text/plain; charset=utf-8", true}
  end

  test "include only the students with a server" do
    student = CourseFactory.build(:student_view)

    assert {DnsRecords.included?({student, nil}),
            DnsRecords.included?({student, ServersFactory.build(:server_view)})} ==
             {false, true}
  end

  test "render the records of each student grouped by domain" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class, name: "ArchiDep 2026")),
      entries: [
        {CourseFactory.build(:student_view, username: "alice", domain: "archidep2.ch"),
         ServersFactory.build(:server_view,
           ip_address: %Postgrex.INET{address: {10, 0, 0, 1}, netmask: 32}
         )},
        {CourseFactory.build(:student_view, username: "bob", domain: "archidep1.ch"),
         ServersFactory.build(:server_view,
           ip_address: %Postgrex.INET{address: {10, 0, 0, 2}, netmask: 32}
         )},
        {CourseFactory.build(:student_view, username: "carol", domain: "archidep2.ch"),
         ServersFactory.build(:server_view,
           ip_address: %Postgrex.INET{address: {10, 0, 0, 3}, netmask: 32}
         )}
      ],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    expected = """
    ; BEGIN DNS records of the servers of the ArchiDep students of class ArchiDep 2026, generated 2026-11-18 14:02 UTC
    ; archidep1.ch
    bob 300 IN A 10.0.0.2
    *.bob 300 IN A 10.0.0.2

    ; archidep2.ch
    alice 300 IN A 10.0.0.1
    *.alice 300 IN A 10.0.0.1
    carol 300 IN A 10.0.0.3
    *.carol 300 IN A 10.0.0.3
    ; END DNS records of the servers of the ArchiDep students of class ArchiDep 2026
    """

    assert {DnsRecords.render(export, false), DnsRecords.render(export, true)} ==
             {expected, expected}
  end

  test "render AAAA records for a server with an IPv6 address" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class, name: "IPv6")),
      entries: [
        {CourseFactory.build(:student_view, username: "dave", domain: "archidep1.ch"),
         ServersFactory.build(:server_view,
           ip_address: %Postgrex.INET{address: {0x2001, 0xDB8, 0, 0, 0, 0, 0, 1}, netmask: 128}
         )}
      ],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert DnsRecords.render(export, false) == """
           ; BEGIN DNS records of the servers of the ArchiDep students of class IPv6, generated 2026-11-18 14:02 UTC
           ; archidep1.ch
           dave 300 IN AAAA 2001:db8::1
           *.dave 300 IN AAAA 2001:db8::1
           ; END DNS records of the servers of the ArchiDep students of class IPv6
           """
  end

  test "render only the comments without students" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class, name: "Empty")),
      entries: [],
      generated_at: ~U[2026-11-18 09:05:00.000000Z]
    }

    assert DnsRecords.render(export, false) == """
           ; BEGIN DNS records of the servers of the ArchiDep students of class Empty, generated 2026-11-18 09:05 UTC
           ; END DNS records of the servers of the ArchiDep students of class Empty
           """
  end
end
