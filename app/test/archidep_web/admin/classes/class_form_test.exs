defmodule ArchiDepWeb.Admin.Classes.ClassFormTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDepWeb.Admin.Classes.ClassForm
  alias ArchiDepWeb.Admin.Classes.ClassFormSshPublicKey
  alias Ecto.Changeset

  # `create_changeset/1` and `update_changeset/2` run the same cast and value
  # validations; each rule is written once below and the `for` comprehension
  # generates one test per changeset function, dispatching through
  # `changeset/2`.
  for variant <- [:create, :update] do
    describe "#{variant}_changeset value validations" do
      test "the name is required" do
        assert errors_on(changeset(unquote(variant), %{"name" => ""})) ==
                 %{name: ["can't be blank"]}
      end

      test "an invalid start date is rejected" do
        assert errors_on(changeset(unquote(variant), %{"name" => "INFO", "start_date" => "nope"})) ==
                 %{start_date: ["is invalid"]}
      end

      test "an invalid end date is rejected" do
        assert errors_on(changeset(unquote(variant), %{"name" => "INFO", "end_date" => "nope"})) ==
                 %{end_date: ["is invalid"]}
      end

      test "a blank teacher SSH public key surfaces a nested error" do
        assert errors_on(
                 changeset(unquote(variant), %{
                   "name" => "INFO",
                   "teacher_ssh_public_keys" => %{"0" => %{"value" => ""}}
                 })
               ) == %{teacher_ssh_public_keys: [%{value: ["can't be blank"]}]}
      end

      test "validation errors accumulate across fields" do
        assert errors_on(changeset(unquote(variant), %{"name" => "", "start_date" => "nope"})) ==
                 %{name: ["can't be blank"], start_date: ["is invalid"]}
      end
    end
  end

  describe "create_changeset/1" do
    test "builds a form from minimal params" do
      changeset = ClassForm.create_changeset(%{"name" => "INFO-2024"})

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %ClassForm{
               name: "INFO-2024",
               start_date: nil,
               end_date: nil,
               active: false,
               servers_enabled: false,
               teacher_ssh_public_keys: [],
               ssh_exercise_vm_md5_host_key_fingerprints: nil,
               ssh_exercise_vm_sha256_host_key_fingerprints: nil
             }
    end

    test "builds a form from full params, coercing the boolean form strings" do
      params = %{
        "name" => "INFO-2024",
        "start_date" => "2024-01-01",
        "end_date" => "2024-06-30",
        "active" => "true",
        "servers_enabled" => "false",
        "teacher_ssh_public_keys" => %{
          "0" => %{"value" => "ssh-ed25519 AAAAKEY1"},
          "1" => %{"value" => "ssh-rsa AAAAKEY2"}
        },
        "ssh_exercise_vm_md5_host_key_fingerprints" => "11:22:33:44",
        "ssh_exercise_vm_sha256_host_key_fingerprints" => "aa:bb:cc:dd"
      }

      changeset = ClassForm.create_changeset(params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %ClassForm{
               name: "INFO-2024",
               start_date: ~D[2024-01-01],
               end_date: ~D[2024-06-30],
               active: true,
               servers_enabled: false,
               teacher_ssh_public_keys: [
                 %ClassFormSshPublicKey{value: "ssh-ed25519 AAAAKEY1"},
                 %ClassFormSshPublicKey{value: "ssh-rsa AAAAKEY2"}
               ],
               ssh_exercise_vm_md5_host_key_fingerprints: "11:22:33:44",
               ssh_exercise_vm_sha256_host_key_fingerprints: "aa:bb:cc:dd"
             }
    end
  end

  describe "update_changeset/2" do
    test "updates every field, coercing the boolean form strings" do
      class =
        build(:class,
          name: "Original",
          start_date: ~D[2024-01-01],
          end_date: ~D[2024-06-30],
          active: false,
          servers_enabled: false,
          teacher_ssh_public_keys: ["ssh-rsa OLDKEY"],
          ssh_exercise_vm_md5_host_key_fingerprints: "11:22:33:44",
          ssh_exercise_vm_sha256_host_key_fingerprints: "aa:bb:cc:dd"
        )

      params = %{
        "name" => "Updated",
        "start_date" => "2025-02-02",
        "end_date" => "2025-07-31",
        "active" => "true",
        "servers_enabled" => "true",
        "teacher_ssh_public_keys" => %{"0" => %{"value" => "ssh-ed25519 NEWKEY"}},
        "ssh_exercise_vm_md5_host_key_fingerprints" => "55:66:77:88",
        "ssh_exercise_vm_sha256_host_key_fingerprints" => "ee:ff:00:11"
      }

      changeset = ClassForm.update_changeset(class, params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %ClassForm{
               name: "Updated",
               start_date: ~D[2025-02-02],
               end_date: ~D[2025-07-31],
               active: true,
               servers_enabled: true,
               teacher_ssh_public_keys: [%ClassFormSshPublicKey{value: "ssh-ed25519 NEWKEY"}],
               ssh_exercise_vm_md5_host_key_fingerprints: "55:66:77:88",
               ssh_exercise_vm_sha256_host_key_fingerprints: "ee:ff:00:11"
             }
    end

    test "clears every optional field when given blank input" do
      class =
        build(:class,
          name: "Original",
          start_date: ~D[2024-01-01],
          end_date: ~D[2024-06-30],
          active: true,
          servers_enabled: true,
          teacher_ssh_public_keys: [],
          ssh_exercise_vm_md5_host_key_fingerprints: "11:22:33:44",
          ssh_exercise_vm_sha256_host_key_fingerprints: "aa:bb:cc:dd"
        )

      params = %{
        "name" => "Original",
        "start_date" => "",
        "end_date" => "",
        "active" => "false",
        "servers_enabled" => "false",
        "ssh_exercise_vm_md5_host_key_fingerprints" => "",
        "ssh_exercise_vm_sha256_host_key_fingerprints" => ""
      }

      changeset = ClassForm.update_changeset(class, params)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %ClassForm{
               name: "Original",
               start_date: nil,
               end_date: nil,
               active: false,
               servers_enabled: false,
               teacher_ssh_public_keys: [],
               ssh_exercise_vm_md5_host_key_fingerprints: nil,
               ssh_exercise_vm_sha256_host_key_fingerprints: nil
             }
    end
  end

  describe "to_class_data/1" do
    test "maps a full form to class data" do
      form = %ClassForm{
        name: "INFO-2024",
        start_date: ~D[2024-01-01],
        end_date: ~D[2024-06-30],
        active: true,
        servers_enabled: false,
        teacher_ssh_public_keys: [
          %ClassFormSshPublicKey{value: "ssh-rsa KEY1"},
          %ClassFormSshPublicKey{value: "ssh-ed25519 KEY2"}
        ],
        ssh_exercise_vm_md5_host_key_fingerprints: "11:22:33:44",
        ssh_exercise_vm_sha256_host_key_fingerprints: "aa:bb:cc:dd"
      }

      assert ClassForm.to_class_data(form) == %{
               name: "INFO-2024",
               start_date: ~D[2024-01-01],
               end_date: ~D[2024-06-30],
               active: true,
               servers_enabled: false,
               teacher_ssh_public_keys: ["ssh-rsa KEY1", "ssh-ed25519 KEY2"],
               ssh_exercise_vm_md5_host_key_fingerprints: "11:22:33:44",
               ssh_exercise_vm_sha256_host_key_fingerprints: "aa:bb:cc:dd"
             }
    end

    test "collapses a single blank key to an empty list" do
      form = %ClassForm{name: "INFO-2024", teacher_ssh_public_keys: [%ClassFormSshPublicKey{}]}

      assert ClassForm.to_class_data(form) == %{
               name: "INFO-2024",
               start_date: nil,
               end_date: nil,
               active: false,
               servers_enabled: false,
               teacher_ssh_public_keys: [],
               ssh_exercise_vm_md5_host_key_fingerprints: nil,
               ssh_exercise_vm_sha256_host_key_fingerprints: nil
             }
    end

    test "maps an empty key list to an empty list" do
      form = %ClassForm{name: "INFO-2024", teacher_ssh_public_keys: []}

      assert ClassForm.to_class_data(form) == %{
               name: "INFO-2024",
               start_date: nil,
               end_date: nil,
               active: false,
               servers_enabled: false,
               teacher_ssh_public_keys: [],
               ssh_exercise_vm_md5_host_key_fingerprints: nil,
               ssh_exercise_vm_sha256_host_key_fingerprints: nil
             }
    end
  end

  describe "add_teacher_ssh_public_key/1" do
    test "appends a blank key to a form that already has keys" do
      form =
        Phoenix.Component.to_form(
          ClassForm.create_changeset(%{
            "name" => "INFO-2024",
            "teacher_ssh_public_keys" => %{"0" => %{"value" => "ssh-ed25519 KEY1"}}
          })
        )

      changeset = ClassForm.add_teacher_ssh_public_key(form)

      assert Changeset.get_field(changeset, :teacher_ssh_public_keys) == [
               %ClassFormSshPublicKey{value: "ssh-ed25519 KEY1"},
               %ClassFormSshPublicKey{}
             ]
    end

    test "appends a blank key to a form with no keys" do
      form = Phoenix.Component.to_form(ClassForm.create_changeset(%{"name" => "INFO-2024"}))

      changeset = ClassForm.add_teacher_ssh_public_key(form)

      assert Changeset.get_field(changeset, :teacher_ssh_public_keys) == [
               %ClassFormSshPublicKey{}
             ]
    end
  end

  defp changeset(:create, params), do: ClassForm.create_changeset(params)
  defp changeset(:update, params), do: ClassForm.update_changeset(build(:class), params)
end
