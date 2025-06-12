defmodule ArchiDep.Servers.Types do
  @type create_server_data :: %{
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t(),
          ssh_port: integer() | nil,
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
