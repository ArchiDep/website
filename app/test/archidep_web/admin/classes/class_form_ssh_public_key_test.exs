defmodule ArchiDepWeb.Admin.Classes.ClassFormSshPublicKeyTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDepWeb.Admin.Classes.ClassFormSshPublicKey
  alias Ecto.Changeset

  describe "new/1" do
    test "builds a public key struct from a value" do
      assert ClassFormSshPublicKey.new("ssh-ed25519 AAAAKEY") ==
               %ClassFormSshPublicKey{value: "ssh-ed25519 AAAAKEY"}
    end
  end

  describe "changeset/2" do
    test "accepts and trims a value" do
      changeset =
        ClassFormSshPublicKey.changeset(%ClassFormSshPublicKey{}, %{
          "value" => "  ssh-ed25519 AAAAKEY  "
        })

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) ==
               %ClassFormSshPublicKey{value: "ssh-ed25519 AAAAKEY"}
    end

    test "requires a value" do
      assert errors_on(ClassFormSshPublicKey.changeset(%ClassFormSshPublicKey{}, %{})) ==
               %{value: ["can't be blank"]}
    end

    test "rejects a whitespace-only value" do
      assert errors_on(
               ClassFormSshPublicKey.changeset(%ClassFormSshPublicKey{}, %{"value" => "   "})
             ) ==
               %{value: ["can't be blank"]}
    end
  end
end
