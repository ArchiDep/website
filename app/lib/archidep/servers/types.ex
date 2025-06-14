defmodule ArchiDep.Servers.Types do
  alias Ecto.UUID

  @type ansible_host :: :inet.ip_address()
  @type ansible_port :: 1..65_535
  @type ansible_user :: String.t()
  @type ansible_playbook_run_state :: :running | :succeeded | :failed | :interrupted | :timeout
  @type ansible_variables :: %{String.t() => String.t()}

  @type create_server_data :: %{
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t(),
          ssh_port: integer() | nil,
          class_id: UUID.t(),
          app_username: String.t(),
          # Expected properties for this server
          expected_cpus: non_neg_integer() | nil,
          expected_cores: non_neg_integer() | nil,
          expected_vcpus: non_neg_integer() | nil,
          expected_memory: non_neg_integer() | nil,
          expected_swap: non_neg_integer() | nil,
          expected_system: String.t() | nil,
          expected_architecture: String.t() | nil,
          expected_os_family: String.t() | nil,
          expected_distribution: String.t() | nil,
          expected_distribution_release: String.t() | nil,
          expected_distribution_version: String.t() | nil
        }

  @type update_server_data :: %{
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t(),
          ssh_port: integer() | nil,
          app_username: String.t(),
          # Expected properties for this server
          expected_cpus: non_neg_integer() | nil,
          expected_cores: non_neg_integer() | nil,
          expected_vcpus: non_neg_integer() | nil,
          expected_memory: non_neg_integer() | nil,
          expected_swap: non_neg_integer() | nil,
          expected_system: String.t() | nil,
          expected_architecture: String.t() | nil,
          expected_os_family: String.t() | nil,
          expected_distribution: String.t() | nil,
          expected_distribution_release: String.t() | nil,
          expected_distribution_version: String.t() | nil
        }
end
