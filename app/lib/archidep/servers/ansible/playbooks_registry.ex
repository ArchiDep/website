defmodule ArchiDep.Servers.Ansible.PlaybooksRegistry do
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook

  @playbooks_dir Path.expand("../../../../priv/ansible/playbooks", __DIR__)
  @playbooks @playbooks_dir
             |> File.ls!()
             |> Enum.filter(&String.ends_with?(&1, ".yml"))
             |> Enum.map(fn filename ->
               digest =
                 Path.join(@playbooks_dir, filename)
                 |> File.stream!(2048)
                 |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
                 |> :crypto.hash_final()

               name = String.replace_suffix(filename, ".yml", "")

               playbook =
                 AnsiblePlaybook.new(Path.join("priv/ansible/playbooks", filename), digest)

               {name, playbook}
             end)
             |> Enum.into(%{})

  def playbook!(name) do
    case Map.fetch(@playbooks, name) do
      {:ok, playbook} ->
        playbook

      :error ->
        raise ArgumentError,
              "Playbook #{name} not found. Available playbooks: #{inspect(Map.keys(@playbooks))}"
    end
  end
end
