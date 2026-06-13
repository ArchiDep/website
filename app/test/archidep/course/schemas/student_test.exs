defmodule ArchiDep.Course.Schemas.StudentTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDep.Course.Schemas.Student
  alias Ecto.Changeset

  # These changeset validations do not depend on the creation timestamp; a fixed
  # instant keeps the changeset calls deterministic.
  @now ~U[2024-01-01 08:00:00.000000Z]

  # A username must be valid as both a Unix user name and a DNS subdomain label,
  # so it may contain only unaccented letters, digits and hyphens and must start
  # with a letter (see the "what is your name" / "change username" dialogs). The
  # values below are each rejected for one of the things we explicitly forbid: a
  # leading digit, a leading hyphen, an underscore (accepted in a Unix name but
  # not a DNS label), a dot, a space, an accent, and other punctuation.
  @forbidden_usernames ["1nope", "-nope", "no_pe", "no.pe", "no pe", "café", "nope!", "no@pe"]
  @username_format_error "must contain only letters (without accents), numbers and hyphens, and start with a letter"

  # `Student.new/3` and `Student.update/3` run the same `validate/1` rules. Each
  # rule is written once below and the `for` comprehension generates one test
  # per changeset function; `student_changeset/2` dispatches to the right
  # constructor. Only rules that validate a *provided* value live here —
  # `validate_required` cannot fail on the update path (an omitted field keeps
  # the persisted value), so the required-field cases live in the `new/3` block
  # below.
  for variant <- [:new, :update] do
    describe "#{variant} value validations" do
      test "the name cannot be longer than 200 characters" do
        assert errors_on(student_changeset(unquote(variant), name: String.duplicate("a", 201))) ==
                 %{name: ["should be at most 200 character(s)"]}
      end

      test "the name is trimmed" do
        assert Changeset.get_change(
                 student_changeset(unquote(variant), name: "  Spaced  "),
                 :name
               ) ==
                 "Spaced"
      end

      test "the email cannot be longer than 255 characters" do
        long_email = String.duplicate("a", 256) <> "@example.ch"

        assert errors_on(student_changeset(unquote(variant), email: long_email)) ==
                 %{email: ["should be at most 255 character(s)"]}
      end

      test "the email must be a valid email address" do
        assert errors_on(student_changeset(unquote(variant), email: "not-an-email")) ==
                 %{email: ["must be a valid email address"]}
      end

      test "the academic class cannot be longer than 30 characters" do
        assert errors_on(
                 student_changeset(unquote(variant), academic_class: String.duplicate("a", 31))
               ) == %{academic_class: ["should be at most 30 character(s)"]}
      end

      test "the username cannot be longer than 20 characters" do
        assert errors_on(student_changeset(unquote(variant), username: String.duplicate("a", 21))) ==
                 %{username: ["should be at most 20 character(s)"]}
      end

      test "the username rejects characters invalid in a Unix name or DNS label" do
        for bad <- @forbidden_usernames do
          assert errors_on(student_changeset(unquote(variant), username: bad)) ==
                   %{username: [@username_format_error]},
                 "expected username #{inspect(bad)} to be rejected"
        end
      end

      test "the username accepts unaccented letters, digits and hyphens" do
        for good <- ["valid-name", "student123", "a", "x-1-y"] do
          assert errors_on(student_changeset(unquote(variant), username: good)) == %{},
                 "expected username #{inspect(good)} to be accepted"
        end
      end

      test "the domain cannot be longer than 50 characters" do
        long_domain = String.duplicate("a", 50) <> ".ch"

        assert errors_on(student_changeset(unquote(variant), domain: long_domain)) ==
                 %{domain: ["should be at most 50 character(s)"]}
      end

      test "the domain must be a valid domain name" do
        assert errors_on(student_changeset(unquote(variant), domain: "not a domain")) ==
                 %{
                   domain: [
                     "must be a valid domain name containing only letters (without accents), numbers and hyphens"
                   ]
                 }
      end

      test "validation errors accumulate across fields" do
        assert errors_on(
                 student_changeset(unquote(variant),
                   name: String.duplicate("a", 201),
                   email: "not-an-email",
                   username: "no_pe",
                   domain: "not a domain"
                 )
               ) == %{
                 name: ["should be at most 200 character(s)"],
                 email: ["must be a valid email address"],
                 username: [@username_format_error],
                 domain: [
                   "must be a valid domain name containing only letters (without accents), numbers and hyphens"
                 ]
               }
      end
    end
  end

  describe "new/3 required fields" do
    test "the name is required" do
      assert errors_on(student_changeset(:new, name: "")) == %{name: ["can't be blank"]}
    end

    test "the email is required" do
      assert errors_on(student_changeset(:new, email: "")) == %{email: ["can't be blank"]}
    end

    test "the username is required" do
      assert errors_on(student_changeset(:new, username: "")) == %{username: ["can't be blank"]}
    end

    test "the domain is required" do
      assert errors_on(student_changeset(:new, domain: "")) == %{domain: ["can't be blank"]}
    end
  end

  describe "new/3 uniqueness within the class" do
    test "the email must not already be taken (case-insensitive)" do
      class = insert(:class, now: @now)
      insert(:student, class: class, email: "taken@example.ch", now: @now)

      assert errors_on(Student.new(build(:student_data, email: "TAKEN@example.ch"), class, @now)) ==
               %{email: ["has already been taken"]}
    end

    test "the username must not already be taken (case-insensitive)" do
      class = insert(:class, now: @now)
      insert(:student, class: class, username: "taken", now: @now)

      assert errors_on(Student.new(build(:student_data, username: "TAKEN"), class, @now)) ==
               %{username: ["has already been taken"]}
    end
  end

  describe "update/3 uniqueness within the class" do
    test "the email must not be taken by another student (case-insensitive)" do
      class = insert(:class, now: @now)
      insert(:student, class: class, email: "taken@example.ch", now: @now)
      student = insert(:student, class: class, now: @now)

      assert errors_on(
               Student.update(student, build(:student_data, email: "TAKEN@example.ch"), @now)
             ) ==
               %{email: ["has already been taken"]}
    end

    test "a student can keep its own email" do
      class = insert(:class, now: @now)
      student = insert(:student, class: class, email: "self@example.ch", now: @now)

      assert errors_on(
               Student.update(student, build(:student_data, email: "self@example.ch"), @now)
             ) ==
               %{}
    end
  end

  describe "configure_changeset/3" do
    test "a valid username with hyphens is accepted" do
      changeset =
        Student.configure_changeset(build(:student), %{username: "valid-name"}, @now)

      assert errors_on(changeset) == %{}
    end

    test "the username is required" do
      changeset = Student.configure_changeset(build(:student, username: nil), %{}, @now)

      assert errors_on(changeset) == %{username: ["can't be blank"]}
    end

    test "the username cannot be longer than 20 characters" do
      changeset =
        Student.configure_changeset(build(:student), %{username: String.duplicate("a", 21)}, @now)

      # The custom message uses the project's `{count}` (CLDR/ICU)
      # interpolation, which is resolved by the translation layer at render
      # time, so the raw changeset error keeps the literal placeholder.
      assert errors_on(changeset) == %{username: ["must be at most {count} characters long"]}
    end

    test "the username rejects characters invalid in a Unix name or DNS label" do
      for bad <- @forbidden_usernames do
        changeset = Student.configure_changeset(build(:student), %{username: bad}, @now)

        assert errors_on(changeset) == %{username: [@username_format_error]},
               "expected username #{inspect(bad)} to be rejected"
      end
    end

    test "username length and format errors accumulate" do
      changeset =
        Student.configure_changeset(
          build(:student),
          %{username: "_" <> String.duplicate("a", 25)},
          @now
        )

      assert errors_on(changeset) == %{
               username: [@username_format_error, "must be at most {count} characters long"]
             }
    end

    test "a student cannot choose the 'archidep' username" do
      changeset = Student.configure_changeset(build(:student), %{username: "archidep"}, @now)

      assert errors_on(changeset) == %{username: ["this username is reserved and cannot be used"]}
    end

    test "confirming a username marks it as confirmed" do
      changeset =
        Student.configure_changeset(
          build(:student, username_confirmed: false),
          %{username: "confirmed"},
          @now
        )

      assert Changeset.get_change(changeset, :username_confirmed) == true
    end
  end

  defp student_changeset(:new, overrides) do
    class = insert(:class, now: @now)
    Student.new(build(:student_data, overrides), class, @now)
  end

  defp student_changeset(:update, overrides) do
    class = insert(:class, now: @now)
    student = insert(:student, class: class, now: @now)
    Student.update(student, build(:student_data, overrides), @now)
  end
end
