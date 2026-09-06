defmodule ArchiDep.Course.Schemas.CourseSessionTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.CourseSite.Session
  alias Ecto.Changeset

  # These changeset rules do not depend on the current time; fixed instants keep
  # the `CourseSession.new/2` and `CourseSession.update/3` calls deterministic.
  @now ~U[2026-09-18 08:00:00.000000Z]
  @later ~U[2026-09-19 09:00:00.000000Z]

  # A number the course does not use. A stored number records what a session
  # said on the day rather than pointing into the course as it stands, so
  # nothing checks it against `ArchiDep.CourseSite.Material`.
  @orphan 99_999

  # `CourseSession.new/2` and `CourseSession.update/3` run the same `validate/1`
  # rules. Each rule is written once below and the `for` comprehension generates
  # one test per changeset function; `changeset/2` dispatches to the right
  # constructor. Only rules that validate a *provided* value live here; the
  # required fields, which the two changesets reject in different situations,
  # have their own blocks further down.
  for variant <- [:new, :update] do
    describe "#{variant} value validations" do
      test "the name cannot be longer than 100 characters" do
        assert errors_on(changeset(unquote(variant), title: String.duplicate("a", 101))) ==
                 %{title: ["should be at most 100 character(s)"]}
      end

      test "a category cannot record a number that numbers no section or chapter" do
        assert errors_on(changeset(unquote(variant), done: [0], due: [-1], next: [100])) == %{
                 done: ["must contain only section or chapter numbers"],
                 due: ["must contain only section or chapter numbers"]
               }
      end

      test "a category may record a number the course no longer has" do
        assert errors_on(changeset(unquote(variant), done: [@orphan], due: [], next: [])) == %{}
      end

      test "validation errors accumulate across fields" do
        assert errors_on(
                 changeset(unquote(variant),
                   title: String.duplicate("a", 101),
                   done: [0],
                   due: [],
                   next: []
                 )
               ) == %{
                 title: ["should be at most 100 character(s)"],
                 done: ["must contain only section or chapter numbers"]
               }
      end
    end
  end

  describe "new/2" do
    test "records the day, the name and the numbers, sorted and de-duplicated" do
      changeset =
        CourseSession.new(
          %{
            date: ~D[2026-10-02],
            title: "  Basic Deployment  ",
            done: [406, 402, 406],
            due: [405, 405],
            next: []
          },
          @now
        )

      assert %CourseSession{id: id} = recorded = Changeset.apply_changes(changeset)

      assert recorded == %CourseSession{
               id: id,
               date: ~D[2026-10-02],
               title: "Basic Deployment",
               done: [402, 406],
               due: [405],
               next: [],
               version: 1,
               created_at: @now,
               updated_at: @now
             }
    end

    test "the day is required" do
      assert errors_on(changeset(:new, date: nil)) == %{date: ["can't be blank"]}
    end

    test "the name is required" do
      assert errors_on(changeset(:new, title: "   ")) == %{title: ["can't be blank"]}
    end
  end

  describe "update/3" do
    test "corrects the day, the name and the numbers, leaving everything else alone" do
      course_session =
        insert(:course_session,
          date: ~D[2026-09-18],
          title: "CLI",
          done: [100],
          due: [101],
          next: [102],
          now: @now
        )

      changeset =
        CourseSession.update(
          course_session,
          %{
            date: ~D[2026-09-19],
            title: "  Command Line  ",
            done: [103, 101, 103],
            due: [],
            next: [102]
          },
          @later
        )

      assert Changeset.apply_changes(changeset) == %{
               course_session
               | date: ~D[2026-09-19],
                 title: "Command Line",
                 done: [101, 103],
                 due: [],
                 next: [102],
                 updated_at: @later
             }

      assert changeset.filters == %{version: course_session.version}
    end

    # A correction carries every field of the form it was made on, so unlike an
    # update built from a partial payload it can blank one out.
    test "the day cannot be cleared" do
      assert errors_on(changeset(:update, date: nil)) == %{date: ["can't be blank"]}
    end

    test "the name cannot be cleared" do
      assert errors_on(changeset(:update, title: "   ")) == %{title: ["can't be blank"]}
    end
  end

  describe "delete/1" do
    test "changes nothing about the session it deletes" do
      course_session = insert(:course_session, now: @now)

      assert CourseSession.delete(course_session).changes == %{}
    end
  end

  describe "to_session/1" do
    test "answers with what the session recorded, as the course material site reads it" do
      course_session =
        build(:course_session,
          date: ~D[2026-09-25],
          title: "SSH",
          done: [102, 103],
          due: [],
          next: [200]
        )

      assert CourseSession.to_session(course_session) ==
               Session.new(~D[2026-09-25], "SSH", [102, 103], [], [200])
    end
  end

  defp changeset(:new, overrides),
    do: :course_session_data |> build(overrides) |> CourseSession.new(@now)

  defp changeset(:update, overrides),
    do:
      :course_session
      |> insert(now: @now)
      |> CourseSession.update(build(:course_session_data, overrides), @later)
end
