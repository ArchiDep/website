defmodule ArchiDepWeb.Admin.Classes.Export.EmailsTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Course.ClassView
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.Emails

  test "describe the format" do
    class = ClassView.from(CourseFactory.build(:class, name: "ArchiDep 2026"))

    assert {Emails.id(), Emails.label(), Emails.filename(class), Emails.content_type(),
            Emails.needs_servers?()} ==
             {"emails", "Emails", "ArchiDep 2026 - emails.txt", "text/plain; charset=utf-8",
              false}
  end

  test "include every student, with or without a server" do
    student = CourseFactory.build(:student_view)

    assert {Emails.included?({student, nil}),
            Emails.included?({student, ServersFactory.build(:server_view)})} == {true, true}
  end

  test "render one email address per line" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class)),
      entries: [
        {CourseFactory.build(:student_view, email: "alice@heig-vd.ch"), nil},
        {CourseFactory.build(:student_view, email: "bob@heig-vd.ch"),
         ServersFactory.build(:server_view)}
      ],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert Emails.render(export, false) == "alice@heig-vd.ch\nbob@heig-vd.ch\n"
    assert Emails.render(export, true) == "alice@heig-vd.ch\nbob@heig-vd.ch\n"
  end

  test "render nothing without students" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class)),
      entries: [],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert Emails.render(export, false) == ""
  end
end
