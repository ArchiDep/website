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

  def new(path, digest) when is_binary(path) and is_binary(digest) do
    %__MODULE__{
      path: path,
      digest: digest
    }
  end
end
