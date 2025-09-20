defmodule ArchiDep.Servers.Ansible.PlaybooksRegistry do
  @moduledoc """
  A registry of the Ansible playbooks bundled with this application in the
  "priv/ansible/playbooks" directory. The names and paths of the playbooks are
  baked into the application at compile time.
  """

  alias ArchiDep.Helpers.FileHelpers
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook

  @playbooks_dir Path.expand("../../../../priv/ansible/playbooks", __DIR__)
  @playbooks_files_digest FileHelpers.hash_files_in_directory!(@playbooks_dir)
  @playbooks @playbooks_dir
             |> File.ls!()
             |> Enum.filter(&String.ends_with?(&1, ".yml"))
             |> Enum.map(fn filename ->
               name = String.replace_suffix(filename, ".yml", "")
               playbook_file = Path.join("priv/ansible/playbooks", filename)

               playbook =
                 AnsiblePlaybook.new(playbook_file, @playbooks_files_digest)

               {name, playbook}
             end)
             |> Enum.into(%{})

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

  defp ansible_files_hash, do: FileHelpers.hash_files_in_directory!(@playbooks_dir)
end
