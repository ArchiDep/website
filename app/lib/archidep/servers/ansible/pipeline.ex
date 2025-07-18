defmodule ArchiDep.Servers.Ansible.Pipeline do
  @moduledoc """
  Default Ansible pipeline identifier.

  When the application starts, this module is used to identify the default
  Ansible pipeline for server management tasks. This allows tests to run a
  different pipeline without needing to change the application configuration.
  """

  @type t :: module
end
