defmodule ArchiDep.Servers.Ansible.PlaybooksRegistry do
  @moduledoc """
  A registry of the Ansible playbooks bundled with this application in the
  "priv/ansible/playbooks" directory. The names and paths of the playbooks are
  baked into the application at compile time.
  """

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

               playbook_file = Path.join("priv/ansible/playbooks", filename)

               playbook =
                 AnsiblePlaybook.new(playbook_file, digest)

               {name, playbook}
             end)
             |> Enum.into(%{})
  @playbooks_files_digest :crypto.hash(
                            :sha256,
                            Path.join(@playbooks_dir, "**/*")
                            |> Path.wildcard()
                            |> Enum.sort()
                            |> Enum.join("\0")
                          )

  for playbook <- Map.values(@playbooks) do
    @external_resource playbook.relative_path
  end

  @spec playbook!(String.t()) :: AnsiblePlaybook.t()
  def playbook!(name) do
    case Map.fetch(@playbooks, name) do
      {:ok, playbook} ->
        playbook

      :error ->
        raise ArgumentError,
              "Playbook #{name} not found. Available playbooks: #{inspect(Map.keys(@playbooks))}"
    end
  end

  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__?, do: @playbooks_files_digest != ansible_files_hash()

  defp ansible_files_hash,
    do:
      :crypto.hash(
        :sha256,
        Path.join(@playbooks_dir, "**/*")
        |> Path.wildcard()
        |> Enum.sort()
        |> Enum.join("\0")
      )
end
