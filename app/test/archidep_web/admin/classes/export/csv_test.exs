defmodule ArchiDepWeb.Admin.Classes.Export.CsvTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Course.ClassView
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.Csv

  test "describe the format" do
    class = ClassView.from(CourseFactory.build(:class, name: "Demo Class"))

    assert {Csv.id(), Csv.label(), Csv.filename(class), Csv.content_type(), Csv.needs_servers?()} ==
             {"csv", "CSV", "Demo Class.csv", "text/csv; charset=utf-8", true}
  end

  test "include every student, with or without a server" do
    student = CourseFactory.build(:student_view)

    assert {Csv.included?({student, nil}),
            Csv.included?({student, ServersFactory.build(:server_view)})} == {true, true}
  end

  test "render a row per student, with the IP address and username of their server" do
    with_server =
      CourseFactory.build(:student_view,
        name: "Alice Cidre",
        academic_class: "CS-1",
        email: "alice@example.com",
        domain: "archidep1.ch"
      )

    without_server =
      CourseFactory.build(:student_view,
        name: "Bob Dupont",
        academic_class: nil,
        email: "bob@example.com",
        domain: "archidep2.ch"
      )

    server =
      ServersFactory.build(:server_view,
        username: "user42",
        ip_address: %Postgrex.INET{address: {10, 0, 0, 42}, netmask: 32}
      )

    export = %Export{
      class: ClassView.from(CourseFactory.build(:class)),
      entries: [{with_server, server}, {without_server, nil}],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    expected =
      "name,class,email,ip,username,domain,comments\n" <>
        "Alice Cidre,CS-1,alice@example.com,10.0.0.42,user42,archidep1.ch,\n" <>
        "Bob Dupont,,bob@example.com,,,archidep2.ch,\n"

    assert {Csv.render(export, false), Csv.render(export, true)} == {expected, expected}
  end

  test "prefix cells a spreadsheet would evaluate as a formula" do
    student =
      CourseFactory.build(:student_view,
        name: "=HYPERLINK(\"http://evil.example.com\")",
        academic_class: "+CS-1",
        email: "-carol@example.com",
        domain: "@carol.archidep.ch"
      )

    server =
      ServersFactory.build(:server_view,
        username: "\tcarol",
        ip_address: %Postgrex.INET{address: {10, 0, 0, 43}, netmask: 32}
      )

    export = %Export{
      class: ClassView.from(CourseFactory.build(:class)),
      entries: [{student, server}],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert Csv.render(export, false) ==
             "name,class,email,ip,username,domain,comments\n" <>
               ~s|"'=HYPERLINK(""http://evil.example.com"")",'+CS-1,| <>
               ~s|'-carol@example.com,10.0.0.43,'\tcarol,'@carol.archidep.ch,\n|
  end

  test "render only the header without students" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class)),
      entries: [],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert Csv.render(export, false) == "name,class,email,ip,username,domain,comments\n"
  end
end
