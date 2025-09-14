defmodule ArchiDep.Course.Schemas.StudentExclusionConstraintTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Support.CourseFactory

  test "exclusion constraint: only one of root or preregistered_user_id is true" do
    student = CourseFactory.build(:student)

    changeset = Student.configure_changeset(student, %{username: "archidep"})

    # get list of error field and message tuples
    assert errors_on(changeset) == %{username: ["this username is reserved and cannot be used"]}
  end
end
