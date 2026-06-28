defmodule ArchiDepWeb.Helpers.StudentHelpersTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Support.CourseFactory
  alias ArchiDepWeb.Helpers.StudentHelpers
  alias Ecto.UUID

  describe "student_not_in_class_tooltip/1" do
    test "names the new class when the student's account is now in a different class" do
      new_class = CourseFactory.build(:class, name: "Advanced Cloud Architecture")
      new_student = CourseFactory.build(:student, class: new_class)

      student =
        CourseFactory.build(:student, user: CourseFactory.build(:user, student: new_student))

      assert StudentHelpers.student_not_in_class_tooltip(student) ==
               "Student now in class Advanced Cloud Architecture"
    end

    test "reports removal when the student's account is no longer in any class" do
      student = CourseFactory.build(:student, user: CourseFactory.build(:user, student: nil))

      assert StudentHelpers.student_not_in_class_tooltip(student) ==
               "Student no longer in this class"
    end

    test "returns nil when the student's account is still this same enrollment" do
      student_id = UUID.generate()
      current = CourseFactory.build(:student, id: student_id, class: CourseFactory.build(:class))

      student =
        CourseFactory.build(:student,
          id: student_id,
          user: CourseFactory.build(:user, student: current)
        )

      assert StudentHelpers.student_not_in_class_tooltip(student) == nil
    end
  end
end
