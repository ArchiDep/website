defmodule ArchiDep.Servers.Schemas.AnsiblePlaybookTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.Schemas.AnsiblePlaybook

  describe "new/2" do
    test "create a playbook from a relative path and a digest" do
      assert AnsiblePlaybook.new("priv/ansible/playbooks/setup.yml", <<1, 2, 3, 4>>) ==
               %AnsiblePlaybook{
                 relative_path: "priv/ansible/playbooks/setup.yml",
                 digest: <<1, 2, 3, 4>>
               }
    end
  end

  describe "name/1" do
    test "derive the name from a nested .yml file path" do
      playbook = AnsiblePlaybook.new("priv/ansible/playbooks/setup.yml", <<0>>)
      assert AnsiblePlaybook.name(playbook) == "setup"
    end

    test "derive the name from a bare .yml file name" do
      playbook = AnsiblePlaybook.new("setup.yml", <<0>>)
      assert AnsiblePlaybook.name(playbook) == "setup"
    end

    test "keep a non-.yml extension in the name" do
      playbook = AnsiblePlaybook.new("priv/ansible/playbooks/setup.yaml", <<0>>)
      assert AnsiblePlaybook.name(playbook) == "setup.yaml"
    end
  end
end
