defmodule ArchiDep.Course.Schemas.StudentTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Support.CourseFactory

  test "a student cannot choose the 'archidep' username" do
    student = CourseFactory.build(:student)

    changeset = Student.configure_changeset(student, %{username: "archidep"})

    # get list of error field and message tuples
    assert errors_on(changeset) == %{username: ["this username is reserved and cannot be used"]}
  end
end
