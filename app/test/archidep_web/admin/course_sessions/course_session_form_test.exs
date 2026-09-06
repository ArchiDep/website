defmodule ArchiDepWeb.Admin.CourseSessions.CourseSessionFormTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDepWeb.Admin.CourseSessions.CourseSessionForm
  alias Ecto.Changeset

  # `create_changeset/1` and `update_changeset/2` run the same cast and value
  # validations; each rule is written once below and the `for` comprehension
  # generates one test per changeset function, dispatching through
  # `changeset/2`.
  for variant <- [:create, :update] do
    describe "#{variant}_changeset value validations" do
      test "the day is required" do
        assert errors_on(changeset(unquote(variant), %{"date" => "", "title" => "CLI"})) ==
                 %{date: ["can't be blank"]}
      end

      test "an invalid day is rejected" do
        assert errors_on(changeset(unquote(variant), %{"date" => "nope", "title" => "CLI"})) ==
                 %{date: ["is invalid"]}
      end

      test "the name is required" do
        assert errors_on(changeset(unquote(variant), %{"date" => "2026-09-18", "title" => ""})) ==
                 %{title: ["can't be blank"]}
      end

      test "a category that is not a set of boxes is rejected" do
        params = %{"date" => "2026-09-18", "title" => "CLI", "done" => "101"}

        assert errors_on(changeset(unquote(variant), params)) == %{done: ["is invalid"]}
      end

      test "validation errors accumulate across fields" do
        assert errors_on(changeset(unquote(variant), %{"date" => "nope", "title" => ""})) ==
                 %{date: ["is invalid"], title: ["can't be blank"]}
      end
    end
  end

  describe "initial_changeset/1" do
    test "starts a form on the day it is given, and nothing else" do
      changeset = CourseSessionForm.initial_changeset(~D[2026-09-18])

      assert errors_on(changeset) == %{title: ["can't be blank"]}

      assert Changeset.apply_changes(changeset) == %CourseSessionForm{
               date: ~D[2026-09-18],
               title: "",
               done: [],
               due: [],
               next: []
             }
    end
  end

  describe "create_changeset/1" do
    test "builds a form from the day and the name alone" do
      changeset = CourseSessionForm.create_changeset(%{"date" => "2026-09-18", "title" => "CLI"})

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %CourseSessionForm{
               date: ~D[2026-09-18],
               title: "CLI",
               done: [],
               due: [],
               next: []
             }
    end

    test "builds a form from every box, keeping the ticked ones as sorted numbers" do
      params = %{
        "date" => "2026-09-18",
        "title" => "CLI",
        "done" => %{"102" => "true", "100" => "true", "101" => "false"},
        "due" => %{"100" => "false", "103" => "true"},
        "next" => %{"104" => "false"}
      }

      changeset = CourseSessionForm.create_changeset(params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %CourseSessionForm{
               date: ~D[2026-09-18],
               title: "CLI",
               done: [100, 102],
               due: [103],
               next: []
             }
    end

    test "ignores a box named something other than a number" do
      params = %{
        "date" => "2026-09-18",
        "title" => "CLI",
        "done" => %{"100" => "true", "101st" => "true", "" => "true"}
      }

      changeset = CourseSessionForm.create_changeset(params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %CourseSessionForm{
               date: ~D[2026-09-18],
               title: "CLI",
               done: [100],
               due: [],
               next: []
             }
    end

    test "builds an empty form when given nothing" do
      changeset = CourseSessionForm.create_changeset()

      assert errors_on(changeset) == %{date: ["can't be blank"], title: ["can't be blank"]}

      assert Changeset.apply_changes(changeset) == %CourseSessionForm{
               date: nil,
               title: "",
               done: [],
               due: [],
               next: []
             }
    end
  end

  describe "update_changeset/2" do
    test "fills the form with what the session recorded when given nothing" do
      course_session =
        build(:course_session,
          date: ~D[2026-09-18],
          title: "CLI",
          done: [100, 101],
          due: [102],
          next: [103]
        )

      changeset = CourseSessionForm.update_changeset(course_session)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %CourseSessionForm{
               date: ~D[2026-09-18],
               title: "CLI",
               done: [100, 101],
               due: [102],
               next: [103]
             }
    end

    test "changes every field" do
      course_session =
        build(:course_session,
          date: ~D[2026-09-18],
          title: "CLI",
          done: [100],
          due: [101],
          next: [102]
        )

      params = %{
        "date" => "2026-09-25",
        "title" => "SSH",
        "done" => %{"100" => "true", "101" => "true"},
        "due" => %{"102" => "true"},
        "next" => %{"103" => "true"}
      }

      changeset = CourseSessionForm.update_changeset(course_session, params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %CourseSessionForm{
               date: ~D[2026-09-25],
               title: "SSH",
               done: [100, 101],
               due: [102],
               next: [103]
             }
    end

    test "empties a category whose every box is unticked" do
      course_session =
        build(:course_session,
          date: ~D[2026-09-18],
          title: "CLI",
          done: [100],
          due: [101],
          next: [102]
        )

      params = %{
        "date" => "2026-09-18",
        "title" => "CLI",
        "done" => %{"100" => "true"},
        "due" => %{"101" => "false"},
        "next" => %{"102" => "false"}
      }

      changeset = CourseSessionForm.update_changeset(course_session, params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %CourseSessionForm{
               date: ~D[2026-09-18],
               title: "CLI",
               done: [100],
               due: [],
               next: []
             }
    end
  end

  describe "to_course_session_data/1" do
    test "maps a full form to the data of a session" do
      form = %CourseSessionForm{
        date: ~D[2026-09-18],
        title: "CLI",
        done: [100, 101],
        due: [102],
        next: [103]
      }

      assert CourseSessionForm.to_course_session_data(form) == %{
               date: ~D[2026-09-18],
               title: "CLI",
               done: [100, 101],
               due: [102],
               next: [103]
             }
    end

    test "maps a form nothing has been ticked in to empty categories" do
      form = %CourseSessionForm{date: ~D[2026-09-18], title: "CLI"}

      assert CourseSessionForm.to_course_session_data(form) == %{
               date: ~D[2026-09-18],
               title: "CLI",
               done: [],
               due: [],
               next: []
             }
    end
  end

  defp changeset(:create, params), do: CourseSessionForm.create_changeset(params)

  defp changeset(:update, params),
    do: CourseSessionForm.update_changeset(build(:course_session), params)
end
