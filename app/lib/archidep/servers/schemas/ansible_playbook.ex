defmodule ArchiDep.Servers.Schemas.AnsiblePlaybook do
  @moduledoc """
  One of the Ansible playbooks bundled with this application.
  """

  @type t :: %__MODULE__{
          path: String.t(),
          digest: binary()
        }

  @enforce_keys [:path, :digest]
  defstruct [:path, :digest]

  @spec name(t()) :: String.t()
  def name(%__MODULE__{path: path}), do: Path.basename(path, ".yml")

  def new(path, digest) when is_binary(path) and is_binary(digest) do
    %__MODULE__{
      path: path,
      digest: digest
    }
  end
end
