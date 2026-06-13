defmodule ArchiDep.Course.Schemas.StudentImportListTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.StudentImportList
  alias Ecto.Changeset

  # Pinned instant passed to `to_insert_data/4`, so the timestamps it stamps on
  # the generated rows can be asserted exactly (see `docs/testing.md`). The
  # schema itself never reads the clock — the use case injects this value.
  @now ~U[2024-03-15 10:30:00.000000Z]

  # Base32 (RFC 4648) alphabet without padding, the encoding
  # `to_insert_data/4` uses for the generated SSH exercise password.
  @base32 ~r/\A[A-Z2-7]+\z/

  describe "changeset/1" do
    test "a valid import list has no errors" do
      changeset = StudentImportList.changeset(valid_import_data())
      assert changeset.valid?
      assert errors_on(changeset) == %{}
    end

    test "the domain is required" do
      changeset = StudentImportList.changeset(import_data(domain: ""))
      assert errors_on(changeset) == %{domain: ["can't be blank"]}
    end

    test "the domain cannot be longer than 20 characters" do
      # A 21-character but otherwise well-formed domain, so only the length rule
      # trips (the format rule passes).
      changeset = StudentImportList.changeset(import_data(domain: "aaaaaaaaaaaaaaaaa.com"))
      assert errors_on(changeset) == %{domain: ["should be at most 20 character(s)"]}
    end

    test "the domain must be a valid domain name" do
      changeset = StudentImportList.changeset(import_data(domain: "not a domain"))

      assert errors_on(changeset) == %{
               domain: [
                 "must be a valid domain name containing only letters (without accents), numbers and hyphens"
               ]
             }
    end

    test "at least one student is required" do
      changeset = StudentImportList.changeset(import_data(students: []))
      assert errors_on(changeset) == %{students: ["can't be blank"]}
    end

    test "each student must have a name" do
      changeset =
        StudentImportList.changeset(import_data(students: [%{name: "", email: "a@b.cd"}]))

      assert errors_on(changeset) == %{students: [%{name: ["can't be blank"]}]}
    end

    test "each student must have an email" do
      changeset =
        StudentImportList.changeset(import_data(students: [%{name: "John Doe", email: ""}]))

      assert errors_on(changeset) == %{students: [%{email: ["can't be blank"]}]}
    end

    test "each student's email must have a valid format" do
      changeset =
        StudentImportList.changeset(
          import_data(students: [%{name: "John Doe", email: "not-an-email"}])
        )

      assert errors_on(changeset) == %{students: [%{email: ["has invalid format"]}]}
    end

    test "student names are trimmed" do
      {:ok, %StudentImportList{students: [student]}} =
        %{students: [%{name: "  John Doe  ", email: "john.doe@example.ch"}]}
        |> import_data()
        |> StudentImportList.changeset()
        |> Changeset.apply_action(:validate)

      assert student.name == "John Doe"
    end
  end

  describe "to_insert_data/4" do
    test "builds an insert row for each student" do
      class = build_class()

      import_list =
        validated(
          import_data(
            academic_class: "BIO-1",
            domain: "example.ch",
            students: [%{name: "John Doe", email: "john.doe@example.ch"}]
          )
        )

      assert [row] = StudentImportList.to_insert_data(import_list, class, [], @now)

      # The generated id and SSH password cannot be pinned, so they are bound
      # and every other field is asserted by full-map equality. The username,
      # though generated, is deterministic given the email and the taken set, so
      # it is pinned here — this schema test is the exhaustive source of truth
      # for the generation algorithm (see `john.doe@…` → `jde` below).
      assert %{id: id, ssh_exercise_password: password} = row

      assert row == %{
               id: id,
               name: "John Doe",
               email: "john.doe@example.ch",
               academic_class: "BIO-1",
               username: "jde",
               username_confirmed: false,
               domain: "example.ch",
               active: true,
               servers_enabled: false,
               ssh_exercise_password: password,
               class_id: class.id,
               version: 1,
               created_at: @now,
               updated_at: @now
             }

      assert {:ok, ^id} = Ecto.UUID.cast(id)
    end

    test "de-duplicates students by email, keeping the first occurrence" do
      class = build_class()

      import_list =
        validated(
          import_data(
            students: [
              %{name: "First", email: "dup@example.ch"},
              %{name: "Second", email: "dup@example.ch"}
            ]
          )
        )

      assert [%{email: "dup@example.ch", name: "First"}] =
               StudentImportList.to_insert_data(import_list, class, [], @now)
    end

    test "preserves the input order of the students" do
      class = build_class()

      import_list =
        validated(
          import_data(
            students: [
              %{name: "A", email: "a@example.ch"},
              %{name: "B", email: "b@example.ch"},
              %{name: "C", email: "c@example.ch"}
            ]
          )
        )

      assert ["a@example.ch", "b@example.ch", "c@example.ch"] =
               import_list
               |> StudentImportList.to_insert_data(class, [], @now)
               |> Enum.map(& &1.email)
    end

    test "derives a username from the email local part" do
      class = build_class()

      import_list =
        validated(
          import_data(
            students: [
              %{name: "John Doe", email: "john.doe@example.ch"},
              %{name: "Jane Smith", email: "jane.smith@example.ch"},
              %{name: "Alice", email: "alice@example.ch"}
            ]
          )
        )

      assert ["jde", "jsh", "ale"] =
               import_list
               |> StudentImportList.to_insert_data(class, [], @now)
               |> Enum.map(& &1.username)
    end

    test "avoids usernames already taken in the class" do
      class = build_class()

      import_list =
        validated(import_data(students: [%{name: "John Doe", email: "john.doe@example.ch"}]))

      # `jde` is the first candidate for `john.doe@…`; with it already taken the
      # next candidate (`jdo`) is chosen instead.
      assert [%{username: "jdo"}] =
               StudentImportList.to_insert_data(import_list, class, ["jde"], @now)
    end

    test "avoids username collisions within the same batch" do
      class = build_class()

      import_list =
        validated(
          import_data(
            students: [
              %{name: "John Doe", email: "john.doe@example.ch"},
              %{name: "Jon Doe", email: "jon.doe@example.ch"}
            ]
          )
        )

      # Both emails derive the same first candidate (`jde`); the second student
      # falls through to the next candidate.
      assert ["jde", "jdo"] =
               import_list
               |> StudentImportList.to_insert_data(class, [], @now)
               |> Enum.map(& &1.username)
    end

    test "falls back to a random username when the email local part is unsuitable" do
      class = build_class()

      import_list =
        validated(import_data(students: [%{name: "Ab", email: "ab@example.ch"}]))

      # The local part is too short to derive a username from, so a random
      # lowercase-alphanumeric username starting with a letter is generated. Its
      # exact value is unpredictable, so only its shape is asserted.
      assert [%{username: username}] =
               StudentImportList.to_insert_data(import_list, class, [], @now)

      assert username =~ ~r/\A[a-z][a-z0-9]+\z/
    end

    test "generates a distinct base32 SSH exercise password per student" do
      class = build_class()

      import_list =
        validated(
          import_data(
            students: [
              %{name: "A", email: "a@example.ch"},
              %{name: "B", email: "b@example.ch"},
              %{name: "C", email: "c@example.ch"}
            ]
          )
        )

      passwords =
        import_list
        |> StudentImportList.to_insert_data(class, [], @now)
        |> Enum.map(& &1.ssh_exercise_password)

      # Each password is 5 random bytes base32-encoded (8 characters). The value
      # is unpinnable, so its encoding is checked and the passwords are required
      # to differ across students.
      assert Enum.all?(passwords, &(String.length(&1) == 8 and &1 =~ @base32))
      assert Enum.uniq(passwords) == passwords
    end

    test "stamps the supplied instant and the use-case defaults on every row" do
      class = build_class()

      import_list =
        validated(
          import_data(
            academic_class: nil,
            students: [%{name: "John Doe", email: "john.doe@example.ch"}]
          )
        )

      assert [row] = StudentImportList.to_insert_data(import_list, class, [], @now)

      assert %{
               academic_class: nil,
               username_confirmed: false,
               active: true,
               servers_enabled: false,
               version: 1,
               created_at: @now,
               updated_at: @now,
               class_id: class_id
             } = row

      assert class_id == class.id
    end
  end

  # The smallest valid import payload: a domain and a single student. Individual
  # tests merge overrides to exercise one rule or behaviour at a time.
  defp valid_import_data,
    do: %{
      academic_class: "BIO-1",
      domain: "example.ch",
      students: [%{name: "John Doe", email: "john.doe@example.ch"}]
    }

  defp import_data(overrides), do: Map.merge(valid_import_data(), Map.new(overrides))

  defp validated(data) do
    {:ok, %StudentImportList{} = import_list} =
      data |> StudentImportList.changeset() |> Changeset.apply_action(:validate)

    import_list
  end

  # A bare class is enough: `to_insert_data/4` reads only its id.
  defp build_class, do: %Class{id: Ecto.UUID.generate(), name: "Test Class"}
end
