defmodule ArchiDepWeb.Admin.Classes.StudentFormTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDepWeb.Admin.Classes.StudentForm
  alias Ecto.Changeset

  # `create_changeset/1` and `update_changeset/2` run the same cast and value
  # validations; each rule is written once below and the `for` comprehension
  # generates one test per changeset function, dispatching through
  # `changeset/2`.
  for variant <- [:create, :update] do
    describe "#{variant}_changeset value validations" do
      test "the required fields cannot be nil" do
        changeset =
          changeset(unquote(variant), %{
            "name" => nil,
            "email" => nil,
            "username" => nil,
            "domain" => nil,
            "active" => nil,
            "servers_enabled" => nil
          })

        assert errors_on(changeset) == %{
                 name: ["cannot be nil"],
                 email: ["cannot be nil"],
                 username: ["cannot be nil"],
                 domain: ["cannot be nil"],
                 active: ["cannot be nil"],
                 servers_enabled: ["cannot be nil"]
               }
      end

      test "an invalid boolean is rejected" do
        assert errors_on(changeset(unquote(variant), %{"active" => "notabool"})) ==
                 %{active: ["is invalid"]}
      end
    end
  end

  describe "create_changeset/1" do
    test "builds a form from minimal params" do
      changeset = StudentForm.create_changeset(%{})

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %StudentForm{
               name: "",
               email: "",
               academic_class: nil,
               username: "",
               domain: "",
               active: true,
               servers_enabled: false
             }
    end

    test "builds a form from full params" do
      params = %{
        "name" => "Jane Doe",
        "email" => "jane@example.com",
        "academic_class" => "CS-101",
        "username" => "jane",
        "domain" => "example.com",
        "active" => "true",
        "servers_enabled" => "false"
      }

      changeset = StudentForm.create_changeset(params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %StudentForm{
               name: "Jane Doe",
               email: "jane@example.com",
               academic_class: "CS-101",
               username: "jane",
               domain: "example.com",
               active: true,
               servers_enabled: false
             }
    end
  end

  describe "update_changeset/2" do
    test "updates every field" do
      student =
        build(:student,
          name: "Original",
          email: "original@example.com",
          academic_class: "Original Class",
          username: "original",
          domain: "original.example.com",
          active: false,
          servers_enabled: false
        )

      params = %{
        "name" => "Updated",
        "email" => "updated@example.com",
        "academic_class" => "Updated Class",
        "username" => "updated",
        "domain" => "updated.example.com",
        "active" => "true",
        "servers_enabled" => "true"
      }

      changeset = StudentForm.update_changeset(student, params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %StudentForm{
               name: "Updated",
               email: "updated@example.com",
               academic_class: "Updated Class",
               username: "updated",
               domain: "updated.example.com",
               active: true,
               servers_enabled: true
             }
    end

    test "clears the academic class when given blank input" do
      student =
        build(:student,
          name: "Original",
          email: "original@example.com",
          academic_class: "Original Class",
          username: "original",
          domain: "original.example.com",
          active: true,
          servers_enabled: true
        )

      params = %{
        "name" => "Original",
        "email" => "original@example.com",
        "academic_class" => "",
        "username" => "original",
        "domain" => "original.example.com",
        "active" => "false",
        "servers_enabled" => "false"
      }

      changeset = StudentForm.update_changeset(student, params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %StudentForm{
               name: "Original",
               email: "original@example.com",
               academic_class: nil,
               username: "original",
               domain: "original.example.com",
               active: false,
               servers_enabled: false
             }
    end
  end

  describe "to_student_data/1" do
    test "maps a full form to student data" do
      form = %StudentForm{
        name: "Jane Doe",
        email: "jane@example.com",
        academic_class: "CS-101",
        username: "jane",
        domain: "example.com",
        active: true,
        servers_enabled: false
      }

      assert StudentForm.to_student_data(form) == %{
               name: "Jane Doe",
               email: "jane@example.com",
               academic_class: "CS-101",
               username: "jane",
               domain: "example.com",
               active: true,
               servers_enabled: false
             }
    end

    test "maps a form without an academic class" do
      form = %StudentForm{
        name: "Jane Doe",
        email: "jane@example.com",
        academic_class: nil,
        username: "jane",
        domain: "example.com",
        active: true,
        servers_enabled: false
      }

      assert StudentForm.to_student_data(form) == %{
               name: "Jane Doe",
               email: "jane@example.com",
               academic_class: nil,
               username: "jane",
               domain: "example.com",
               active: true,
               servers_enabled: false
             }
    end
  end

  defp changeset(:create, params), do: StudentForm.create_changeset(params)
  defp changeset(:update, params), do: StudentForm.update_changeset(build(:student), params)
end
