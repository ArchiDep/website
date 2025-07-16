defmodule ArchiDep.Servers.Schemas.AnsiblePlaybook do
  @moduledoc """
  One of the Ansible playbooks bundled with this application.

  Also see `ArchiDep.Servers.Ansible.PlaybooksRegistry` which compiles playbooks
  into the application.
  """

  @type t :: %__MODULE__{
          relative_path: String.t(),
          digest: binary()
        }

  @enforce_keys [:relative_path, :digest]
  defstruct [:relative_path, :digest]

  @spec name(t()) :: String.t()
  def name(%__MODULE__{relative_path: relative_path}), do: Path.basename(relative_path, ".yml")

  def new(relative_path, digest) when is_binary(relative_path) and is_binary(digest) do
    %__MODULE__{
      relative_path: relative_path,
      digest: digest
    }
  end
end
