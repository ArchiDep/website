defmodule ArchiDepWeb.Admin.Classes.Export.SshExerciseInventoryTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Course.ClassView
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.SshExerciseInventory

  test "describe the format" do
    class = ClassView.from(CourseFactory.build(:class, name: "Demo Class"))

    assert {SshExerciseInventory.id(), SshExerciseInventory.label(),
            SshExerciseInventory.filename(class), SshExerciseInventory.content_type(),
            SshExerciseInventory.needs_servers?()} ==
             {"ssh-exercise-inventory", "SSH exercise inventory", "inventory.yml",
              "application/json; charset=utf-8", false}
  end

  test "include every student, with or without a server" do
    student = CourseFactory.build(:student_view)

    assert {SshExerciseInventory.included?({student, nil}),
            SshExerciseInventory.included?({student, ServersFactory.build(:server_view)})} ==
             {true, true}
  end

  test "render the username and password of each student" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class)),
      entries: [
        {CourseFactory.build(:student_view, username: "alice", ssh_exercise_password: "a-secret"),
         nil},
        {CourseFactory.build(:student_view, username: "bob", ssh_exercise_password: "b-secret"),
         nil}
      ],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert export |> SshExerciseInventory.render(false) |> Jason.decode!() == %{
             "students" => [
               %{"username" => "alice", "password" => "a-secret"},
               %{"username" => "bob", "password" => "b-secret"}
             ]
           }
  end

  test "redact the passwords" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class)),
      entries: [
        {CourseFactory.build(:student_view, username: "carol", ssh_exercise_password: "c-secret"),
         nil}
      ],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert export |> SshExerciseInventory.render(true) |> Jason.decode!() == %{
             "students" => [%{"username" => "carol", "password" => "***"}]
           }
  end

  test "render an empty inventory without students" do
    export = %Export{
      class: ClassView.from(CourseFactory.build(:class)),
      entries: [],
      generated_at: ~U[2026-11-18 14:02:17.000000Z]
    }

    assert export |> SshExerciseInventory.render(false) |> Jason.decode!() == %{"students" => []}
  end
end
