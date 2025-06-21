defmodule ArchiDep.Servers.Types do
  alias Ecto.UUID

  @type ansible_host :: :inet.ip_address()
  @type ansible_port :: 1..65_535
  @type ansible_user :: String.t()
  @type ansible_playbook_run_state ::
          :pending | :running | :succeeded | ansible_playbook_run_failed_state()
  @type ansible_playbook_run_failed_state :: :failed | :interrupted | :timeout
  @type ansible_variables :: %{String.t() => String.t()}
  @type ansible_stats :: %{
          changed: non_neg_integer(),
          failures: non_neg_integer(),
          ignored: non_neg_integer(),
          ok: non_neg_integer(),
          rescued: non_neg_integer(),
          skipped: non_neg_integer(),
          unreachable: non_neg_integer()
        }

  @type server_job ::
          :connecting
          | :reconnecting
          | :checking_access
          | :setting_up_app_user
          | :gathering_facts
          | {:running_playbook, String.t(), UUID.t()}
          | nil

  @type server_ansible_playbook_failed ::
          {:server_ansible_playbook_failed, String.t(), ansible_playbook_run_failed_state(),
           ansible_stats()}
  @type server_authentication_failed_problem ::
          {:server_authentication_failed, :username | :app_username, String.t()}
  @type server_expected_property_mismatch_problem ::
          {:server_expected_property_mismatch, atom(), term(), term()}
  @type server_fact_gathering_failed_problem :: {:server_fact_gathering_failed, term()}
  @type server_missing_sudo_access_problem ::
          {:server_missing_sudo_access, String.t(), String.t()}
  @type server_reconnection_failed_problem :: {:server_reconnection_failed, term()}
  @type server_sudo_access_check_failed_problem :: {:server_sudo_access_check_failed, term()}
  @type server_problem ::
          server_ansible_playbook_failed()
          | server_authentication_failed_problem()
          | server_expected_property_mismatch_problem()
          | server_fact_gathering_failed_problem()
          | server_missing_sudo_access_problem()
          | server_reconnection_failed_problem()
          | server_sudo_access_check_failed_problem()

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
