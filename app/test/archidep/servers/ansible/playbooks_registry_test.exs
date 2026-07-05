defmodule ArchiDep.Servers.Ansible.PlaybooksRegistryTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.Ansible.PlaybooksRegistry
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook

  describe "playbook!/1" do
    test "returns the bundled setup playbook" do
      playbook = PlaybooksRegistry.playbook!("setup")

      # The digest is the compile-time content hash of the playbooks directory;
      # bind it from the result and pin the rest of the struct.
      assert playbook == %AnsiblePlaybook{
               relative_path: "priv/ansible/playbooks/setup.yml",
               digest: playbook.digest
             }

      assert byte_size(playbook.digest) == 32
    end

    test "raises with the available playbooks for an unknown name" do
      assert_raise ArgumentError,
                   ~s(Playbook nope not found. Available playbooks: ["setup"]),
                   fn -> PlaybooksRegistry.playbook!("nope") end
    end
  end
end
