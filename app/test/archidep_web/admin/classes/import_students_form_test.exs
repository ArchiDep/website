defmodule ArchiDepWeb.Admin.Classes.ImportStudentsFormTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDepWeb.Admin.Classes.ImportStudentsForm

  describe "changeset/2" do
    test "requires the name column, email column and domain" do
      assert errors_on(ImportStudentsForm.changeset(%{}, [])) == %{
               name_column: ["can't be blank"],
               email_column: ["can't be blank"],
               domain: ["can't be blank"]
             }
    end

    test "accepts a valid column mapping" do
      students = [
        %{"Name" => "Alice", "Email" => "alice@example.com"},
        %{"Name" => "Bob", "Email" => "bob@example.com"}
      ]

      changeset =
        ImportStudentsForm.changeset(
          %{"name_column" => "Name", "email_column" => "Email", "domain" => "archidep.ch"},
          students
        )

      assert errors_on(changeset) == %{}
    end

    test "rejects a name column that looks like it contains emails" do
      students = [
        %{"Name" => "alice@example.com", "Email" => "alice@example.com"},
        %{"Name" => "bob@example.com", "Email" => "bob@example.com"}
      ]

      changeset =
        ImportStudentsForm.changeset(
          %{"name_column" => "Name", "email_column" => "Email", "domain" => "archidep.ch"},
          students
        )

      assert errors_on(changeset) == %{
               name_column: ["this column looks like it contains emails, not names"]
             }
    end

    test "rejects a name column with too few unique names" do
      students = [
        %{"Name" => "Alice", "Email" => "alice@example.com"},
        %{"Name" => "Alice", "Email" => "bob@example.com"}
      ]

      changeset =
        ImportStudentsForm.changeset(
          %{"name_column" => "Name", "email_column" => "Email", "domain" => "archidep.ch"},
          students
        )

      assert errors_on(changeset) == %{
               name_column: ["only 1 unique name out of 2 in this column"]
             }
    end

    test "rejects an email column with no email" do
      students = [
        %{"Name" => "Alice", "Email" => "alice"},
        %{"Name" => "Bob", "Email" => "bob"}
      ]

      changeset =
        ImportStudentsForm.changeset(
          %{"name_column" => "Name", "email_column" => "Email", "domain" => "archidep.ch"},
          students
        )

      assert errors_on(changeset) == %{email_column: ["no email found in this column"]}
    end

    test "rejects an email column with duplicate emails" do
      students = [
        %{"Name" => "Alice", "Email" => "shared@example.com"},
        %{"Name" => "Bob", "Email" => "shared@example.com"}
      ]

      changeset =
        ImportStudentsForm.changeset(
          %{"name_column" => "Name", "email_column" => "Email", "domain" => "archidep.ch"},
          students
        )

      assert errors_on(changeset) == %{email_column: ["duplicate emails found in this column"]}
    end

    test "rejects an academic class longer than 30 characters" do
      students = [
        %{"Name" => "Alice", "Email" => "alice@example.com"},
        %{"Name" => "Bob", "Email" => "bob@example.com"}
      ]

      changeset =
        ImportStudentsForm.changeset(
          %{
            "name_column" => "Name",
            "email_column" => "Email",
            "academic_class" => String.duplicate("a", 31),
            "domain" => "archidep.ch"
          },
          students
        )

      assert errors_on(changeset) == %{academic_class: ["should be at most 30 character(s)"]}
    end

    test "rejects a domain longer than 20 characters" do
      students = [
        %{"Name" => "Alice", "Email" => "alice@example.com"},
        %{"Name" => "Bob", "Email" => "bob@example.com"}
      ]

      changeset =
        ImportStudentsForm.changeset(
          %{
            "name_column" => "Name",
            "email_column" => "Email",
            "domain" => "aaaaaaaaaaaaaaaaaa.ch"
          },
          students
        )

      assert errors_on(changeset) == %{domain: ["should be at most 20 character(s)"]}
    end

    test "rejects a domain with an invalid format" do
      students = [
        %{"Name" => "Alice", "Email" => "alice@example.com"},
        %{"Name" => "Bob", "Email" => "bob@example.com"}
      ]

      changeset =
        ImportStudentsForm.changeset(
          %{"name_column" => "Name", "email_column" => "Email", "domain" => "not a domain"},
          students
        )

      assert errors_on(changeset) == %{
               domain: [
                 "must be a valid domain name containing only letters (without accents), numbers and hyphens"
               ]
             }
    end
  end
end
