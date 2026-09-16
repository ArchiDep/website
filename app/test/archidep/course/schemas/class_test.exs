defmodule ArchiDep.Course.Schemas.ClassTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Servers.SSH.SSHHostKey
  alias ArchiDep.Support.SSHFactory
  alias Ecto.Changeset

  # These changeset validations do not depend on the creation timestamp; a fixed
  # instant keeps the `Class.new/2` and `Class.update/3` calls deterministic.
  @now ~U[2024-01-01 08:00:00.000000Z]

  describe "teacher SSH public keys" do
    test "accept valid SSH public keys" do
      valid_keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEArandomkey== user@host",
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC3randomkey== user@host"
      ]

      changeset =
        :class_data
        |> build(teacher_ssh_public_keys: valid_keys)
        |> Class.new(@now)

      assert errors_on(changeset) == %{}
    end

    test "reject duplicate SSH public keys" do
      key = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEArandomkey== user@host"

      changeset =
        :class_data
        |> build(teacher_ssh_public_keys: [key, key])
        |> Class.new(@now)

      assert errors_on(changeset) == %{
               teacher_ssh_public_keys: [
                 "must not contain duplicate keys (key #2 is a duplicate of a previous key)"
               ]
             }
    end

    test "reject malformed SSH public keys" do
      keys = [
        "not-a-key",
        "ssh-foo"
      ]

      changeset =
        :class_data
        |> build(teacher_ssh_public_keys: keys)
        |> Class.new(@now)

      assert errors_on(changeset) == %{
               teacher_ssh_public_keys: [
                 "must contain valid SSH public keys (key #1 does not start with 'ssh-<type>')",
                 "must contain valid SSH public keys (key #2 does not start with 'ssh-<type>')"
               ]
             }
    end

    test "reject keys that are too long" do
      long_key = "ssh-rsa " <> String.duplicate("A", 2001)

      changeset =
        :class_data
        |> build(teacher_ssh_public_keys: [long_key])
        |> Class.new(@now)

      assert errors_on(changeset) == %{
               teacher_ssh_public_keys: [
                 "must contains keys at most 2000 characters long (key #1 is 2009 characters long)"
               ]
             }
    end

    test "accept empty list of keys" do
      changeset =
        :class_data
        |> build(teacher_ssh_public_keys: [])
        |> Class.new(@now)

      assert errors_on(changeset) == %{}
    end
  end

  # `Class.new/2` and `Class.update/3` run the same `validate/1` rules. Each
  # rule is written once below and the `for` comprehension generates one test
  # per changeset function; `changeset/2` dispatches to the right constructor.
  # Only rules that validate a *provided* value live here — `validate_required`
  # cannot fail on the update path (an omitted field keeps the persisted value),
  # so the required-field cases live in the `new/2` block further down.
  for variant <- [:new, :update] do
    describe "#{variant} value validations" do
      test "the name cannot be longer than 50 characters" do
        assert errors_on(changeset(unquote(variant), name: String.duplicate("a", 51))) ==
                 %{name: ["should be at most 50 character(s)"]}
      end

      test "the name is trimmed" do
        assert Changeset.get_change(changeset(unquote(variant), name: "  Spaced  "), :name) ==
                 "Spaced"
      end

      test "the end date cannot be before the start date" do
        assert errors_on(
                 changeset(unquote(variant),
                   start_date: ~D[2024-02-01],
                   end_date: ~D[2024-01-01]
                 )
               ) == %{end_date: ["must be after the start date"]}
      end

      test "the start and end dates may be equal" do
        assert errors_on(
                 changeset(unquote(variant),
                   start_date: ~D[2024-01-01],
                   end_date: ~D[2024-01-01]
                 )
               ) == %{}
      end

      test "an open-ended date window is valid" do
        assert errors_on(changeset(unquote(variant), start_date: nil, end_date: ~D[2024-12-31])) ==
                 %{}

        assert errors_on(changeset(unquote(variant), start_date: ~D[2024-01-01], end_date: nil)) ==
                 %{}
      end

      test "exercise VM host keys must be valid SSH public keys" do
        assert errors_on(
                 changeset(unquote(variant),
                   ssh_exercise_vm_host_keys:
                     "256 SHA256:V0jnGyjc86bi1R3vTmyML4bwnqc/WVEK+Y0M09I3rWY root@vm (ED25519)"
                 )
               ) == %{
                 ssh_exercise_vm_host_keys: [
                   "must contain only SSH public keys, one per line (invalid lines: {lines})"
                 ]
               }
      end

      test "exercise VM host keys must not contain a private key" do
        assert errors_on(
                 changeset(unquote(variant),
                   ssh_exercise_vm_host_keys: """
                   -----BEGIN OPENSSH PRIVATE KEY-----
                   (key material)
                   -----END OPENSSH PRIVATE KEY-----
                   """
                 )
               ) == %{
                 ssh_exercise_vm_host_keys: [
                   "must not contain a private key: only provide the public keys (the .pub files), and never share a private key"
                 ]
               }
      end

      test "valid exercise VM host keys are accepted" do
        assert errors_on(
                 changeset(unquote(variant),
                   ssh_exercise_vm_host_keys: SSHFactory.random_ssh_host_keys()
                 )
               ) == %{}
      end

      test "validation errors accumulate across fields" do
        assert errors_on(
                 changeset(unquote(variant),
                   name: String.duplicate("a", 51),
                   start_date: ~D[2024-02-01],
                   end_date: ~D[2024-01-01],
                   ssh_exercise_vm_host_keys: "not a key"
                 )
               ) == %{
                 name: ["should be at most 50 character(s)"],
                 end_date: ["must be after the start date"],
                 ssh_exercise_vm_host_keys: [
                   "must contain only SSH public keys, one per line (invalid lines: {lines})"
                 ]
               }
      end
    end
  end

  describe "update/3 exercise VM host keys" do
    test "stores the keys in their normalized format" do
      class = insert(:class, ssh_exercise_vm_host_keys: nil, now: @now)
      first_key = SSHFactory.random_ssh_host_key()
      second_key = SSHFactory.random_ssh_host_key()

      changeset =
        Class.update(
          class,
          %{
            ssh_exercise_vm_host_keys: """
            #{SSHHostKey.to_openssh(first_key)} root@vm
            ssh.archidep.ch #{SSHHostKey.to_openssh(second_key)}
            """
          },
          @now
        )

      assert Changeset.apply_changes(changeset) == %{
               (class
                |> Repo.reload!()
                |> Repo.preload(:expected_server_properties))
               | ssh_exercise_vm_host_keys:
                   "#{SSHHostKey.to_openssh(first_key)}\n#{SSHHostKey.to_openssh(second_key)}",
                 updated_at: @now
             }
    end

    test "clears blank keys" do
      class =
        insert(:class, ssh_exercise_vm_host_keys: SSHFactory.random_ssh_host_keys(), now: @now)

      changeset = Class.update(class, %{ssh_exercise_vm_host_keys: " \n "}, @now)

      assert Changeset.apply_changes(changeset) == %{
               (class
                |> Repo.reload!()
                |> Repo.preload(:expected_server_properties))
               | ssh_exercise_vm_host_keys: nil,
                 updated_at: @now
             }
    end
  end

  describe "new/2 required fields" do
    test "the name is required" do
      assert errors_on(changeset(:new, name: "")) == %{name: ["can't be blank"]}
    end

    test "active is required" do
      assert errors_on(changeset(:new, active: nil)) == %{active: ["can't be blank"]}
    end

    test "servers_enabled is required" do
      assert errors_on(changeset(:new, servers_enabled: nil)) ==
               %{servers_enabled: ["can't be blank"]}
    end
  end

  describe "new/2 name uniqueness" do
    test "the name must not already be taken (case-insensitive)" do
      insert(:class, name: "INFO-2024", now: @now)

      assert errors_on(changeset(:new, name: "info-2024")) == %{name: ["has already been taken"]}
    end
  end

  describe "new/2 name uniqueness at the database" do
    test "a name taken after the changeset was built is an error, not a raise" do
      changeset = changeset(:new, name: "raced-2024")

      insert(:class, name: "RACED-2024", now: @now)

      assert {:error, conflicted} = Repo.insert(changeset)
      assert errors_on(conflicted) == %{name: ["has already been taken"]}
    end
  end

  describe "update/3 name uniqueness" do
    test "the name must not be taken by another class (case-insensitive)" do
      insert(:class, name: "INFO-2024", now: @now)
      other = insert(:class, name: "MATH-2024", now: @now)

      assert errors_on(Class.update(other, build(:class_data, name: "info-2024"), @now)) ==
               %{name: ["has already been taken"]}
    end

    test "a class can keep its own name" do
      class = insert(:class, name: "INFO-2024", now: @now)

      assert errors_on(
               Class.update(class, build(:class_data, name: "INFO-2024", now: @now), @now)
             ) ==
               %{}
    end
  end

  describe "update_expected_server_properties/3" do
    # The exhaustive expected-server-properties rules live in
    # `ExpectedServerPropertiesTest`; here we only prove the nested changeset is
    # cast and its (accumulated) errors surface under the association.
    test "surfaces nested expected-server-properties validation errors" do
      class = insert(:class, now: @now)

      changeset = Class.update_expected_server_properties(class, %{cpus: 0, memory: 0}, @now)

      assert errors_on(changeset) == %{
               expected_server_properties: %{
                 cpus: ["must be between 1 and {number}"],
                 memory: ["must be between 1 and {number}"]
               }
             }
    end
  end

  defp changeset(:new, overrides),
    do: :class_data |> build(overrides) |> Class.new(@now)

  defp changeset(:update, overrides),
    do: :class |> insert(now: @now) |> Class.update(build(:class_data, overrides), @now)
end
