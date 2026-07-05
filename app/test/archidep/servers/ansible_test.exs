defmodule ArchiDep.Servers.AnsibleTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.PlaybooksRegistry

  describe "playbook!/1" do
    test "returns the setup playbook from the registry" do
      assert Ansible.playbook!("setup") == PlaybooksRegistry.playbook!("setup")
    end

    test "raises for any other playbook name" do
      assert_raise FunctionClauseError, fn -> Ansible.playbook!("nope") end
    end
  end
end
