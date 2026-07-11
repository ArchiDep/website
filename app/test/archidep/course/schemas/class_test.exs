defmodule ArchiDep.Course.Schemas.ClassTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Support.SSHFactory
  alias Ecto.Changeset

  # These changeset validations do not depend on the creation timestamp; a fixed
  # instant keeps the `Class.new/2` and `Class.update/3` calls deterministic.
  @now ~U[2024-01-01 08:00:00.000000Z]

  # A later instant for the broadcast payloads a refresh applies, distinct from
  # the persisted fixtures' timestamps.
  @later ~U[2024-06-01 12:00:00.000000Z]

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

      # A SHA256-format fingerprint is a well-formed line that is not a valid
      # MD5 fingerprint, so it exercises the error path. (A line that matches no
      # fingerprint format at all currently raises in the SSH parser rather than
      # returning an error — see
      # ArchiDep.Servers.SSH.SSHKeyFingerprint.parse/2.)
      test "MD5 host key fingerprints must be valid" do
        assert errors_on(
                 changeset(unquote(variant),
                   ssh_exercise_vm_md5_host_key_fingerprints:
                     SSHFactory.random_ssh_host_key_fingerprint_string(:sha256)
                 )
               ) == %{
                 ssh_exercise_vm_md5_host_key_fingerprints: [
                   "must contain at least one valid SSH host key fingerprint in MD5 format, with new lines between each fingerprint"
                 ]
               }
      end

      test "valid MD5 host key fingerprints are accepted" do
        assert errors_on(
                 changeset(unquote(variant),
                   ssh_exercise_vm_md5_host_key_fingerprints:
                     SSHFactory.random_ssh_host_key_fingerprint_string(:md5)
                 )
               ) == %{}
      end

      # Regression guard for the error-key bug: this branch used to add its
      # error under `:ssh_exercise_vm_host_key_fingerprints` (a field that does
      # not exist), so the error never reached the form. It must surface on the
      # SHA256 field.
      test "SHA256 host key fingerprints must be valid" do
        assert errors_on(
                 changeset(unquote(variant),
                   ssh_exercise_vm_sha256_host_key_fingerprints:
                     SSHFactory.random_ssh_host_key_fingerprint_string(:md5)
                 )
               ) == %{
                 ssh_exercise_vm_sha256_host_key_fingerprints: [
                   "must contain at least one valid SSH host key fingerprint, with new lines between each fingerprint"
                 ]
               }
      end

      test "valid SHA256 host key fingerprints are accepted" do
        assert errors_on(
                 changeset(unquote(variant),
                   ssh_exercise_vm_sha256_host_key_fingerprints:
                     SSHFactory.random_ssh_host_key_fingerprint_string(:sha256)
                 )
               ) == %{}
      end

      test "validation errors accumulate across fields" do
        assert errors_on(
                 changeset(unquote(variant),
                   name: String.duplicate("a", 51),
                   start_date: ~D[2024-02-01],
                   end_date: ~D[2024-01-01],
                   ssh_exercise_vm_sha256_host_key_fingerprints:
                     SSHFactory.random_ssh_host_key_fingerprint_string(:md5)
                 )
               ) == %{
                 name: ["should be at most 50 character(s)"],
                 end_date: ["must be after the start date"],
                 ssh_exercise_vm_sha256_host_key_fingerprints: [
                   "must contain at least one valid SSH host key fingerprint, with new lines between each fingerprint"
                 ]
               }
      end
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

  describe "refresh!/2" do
    test "merges an incoming class broadcast one version ahead into the cached class" do
      class = insert(:class, now: @now)
      {:ok, cached} = Class.fetch_class(class.id)

      # The broadcast carries the next version and diverges from the persisted
      # row on every asserted field, so the assertion can only pass if the
      # in-memory merge ran: the catch-all fallback would re-fetch and return
      # the persisted values instead.
      updated = %{
        cached
        | name: "Renamed class",
          start_date: ~D[2024-02-01],
          end_date: ~D[2024-11-30],
          active: not cached.active,
          servers_enabled: not cached.servers_enabled,
          teacher_ssh_public_keys: ["ssh-ed25519 AAAAsentinel comment"],
          version: cached.version + 1,
          updated_at: @later
      }

      assert Class.refresh!(cached, updated) == %{
               cached
               | name: "Renamed class",
                 start_date: ~D[2024-02-01],
                 end_date: ~D[2024-11-30],
                 active: updated.active,
                 servers_enabled: updated.servers_enabled,
                 teacher_ssh_public_keys: ["ssh-ed25519 AAAAsentinel comment"],
                 version: cached.version + 1,
                 updated_at: @later
             }
    end

    test "ignores a class broadcast at or below the cached version" do
      class = insert(:class, now: @now)
      {:ok, cached} = Class.fetch_class(class.id)

      stale = %{cached | name: "Ignored", version: cached.version, updated_at: @later}

      assert Class.refresh!(cached, stale) == cached
    end

    test "re-fetches from the database when the incoming version skips ahead" do
      class = insert(:class, now: @now)
      {:ok, cached} = Class.fetch_class(class.id)

      {1, nil} =
        Repo.update_all(
          from(c in Class, where: c.id == ^cached.id),
          set: [name: "Persisted rename", version: cached.version + 2, updated_at: @later]
        )

      {:ok, fresh} = Class.fetch_class(cached.id)
      refute fresh == cached

      gapped = %{cached | name: "Ignored", version: cached.version + 2, updated_at: @later}

      assert Class.refresh!(cached, gapped) == fresh
    end
  end

  defp changeset(:new, overrides),
    do: :class_data |> build(overrides) |> Class.new(@now)

  defp changeset(:update, overrides),
    do: :class |> insert(now: @now) |> Class.update(build(:class_data, overrides), @now)
end
