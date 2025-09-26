defmodule ArchiDep.Course.Schemas.ClassTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.CourseFactory
  alias ArchiDep.Course.Schemas.Class

  describe "validations" do
    test "accept valid SSH public keys" do
      valid_keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEArandomkey== user@host",
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC3randomkey== user@host"
      ]

      changeset =
        :class_data
        |> build(teacher_ssh_public_keys: valid_keys)
        |> Class.new()

      assert errors_on(changeset) == %{}
    end

    test "reject duplicate SSH public keys" do
      key = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEArandomkey== user@host"

      changeset =
        :class_data
        |> build(teacher_ssh_public_keys: [key, key])
        |> Class.new()

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
        |> Class.new()

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
        |> Class.new()

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
        |> Class.new()

      assert errors_on(changeset) == %{}
    end
  end
end
