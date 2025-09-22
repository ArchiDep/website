defmodule ArchiDep.Servers.ServerTracking.ServerProblems do
  @moduledoc """
  Helper functions to create and identify server problems.
  """

  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types

  @spec server_problem?(list(atom())) :: (Types.server_problem() -> boolean())
  def server_problem?(problem_types) when is_list(problem_types),
    do: &(elem(&1, 0) in problem_types)

  @spec server_problem?(atom()) :: (Types.server_problem() -> boolean())
  def server_problem?(type), do: &(elem(&1, 0) == type)

  @spec server_ansible_playbook_failed_problem(AnsiblePlaybookRun.t()) ::
          Types.server_ansible_playbook_failed_problem()
  def server_ansible_playbook_failed_problem(playbook_run),
    do:
      {:server_ansible_playbook_failed, playbook_run.playbook, playbook_run.state,
       AnsiblePlaybookRun.stats(playbook_run)}

  @spec server_ansible_playbook_repeatedly_failed_problem(list(AnsiblePlaybookRun.t())) ::
          Types.server_ansible_playbook_repeatedly_failed_problem()
  def server_ansible_playbook_repeatedly_failed_problem(playbook_runs),
    do:
      {:server_ansible_playbook_repeatedly_failed,
       Enum.map(playbook_runs, &{&1.playbook, &1.state, AnsiblePlaybookRun.stats(&1)})}

  @spec server_ansible_playbook_failed_problem?(String.t()) :: (Types.server_problem() ->
                                                                  boolean())
  def server_ansible_playbook_failed_problem?(playbook),
    do: &match?({:server_ansible_playbook_failed, ^playbook, _state, _stats}, &1)

  @spec server_key_exchange_failed_problem?() :: (Types.server_problem() -> boolean())
  def server_key_exchange_failed_problem?, do: server_problem?(:server_key_exchange_failed)

  @spec server_expected_property_mismatch_problem?(atom()) :: (Types.server_problem() ->
                                                                 boolean())
  def server_expected_property_mismatch_problem?(property) when is_atom(property),
    do: &match?({:server_expected_property_mismatch, ^property, _expected, _actual}, &1)

  @spec server_expected_property_mismatch_problem?((atom() -> boolean())) ::
          (Types.server_problem() ->
             boolean())
  def server_expected_property_mismatch_problem?(predicate) when is_function(predicate, 1),
    do: fn
      {:server_expected_property_mismatch, property, _expected, _actual} ->
        predicate.(property)

      _any_other_kind_of_problem ->
        false
    end

  @spec server_authentication_failed_problem(Server.t(), String.t()) ::
          Types.server_authentication_failed_problem()
  def server_authentication_failed_problem(%Server{app_username: app_username}, app_username),
    do: {:server_authentication_failed, :app_username, app_username}

  def server_authentication_failed_problem(_server, username),
    do: {:server_authentication_failed, :username, username}

  @spec server_connection_timed_out_problem(Server.t(), String.t()) ::
          Types.server_connection_timed_out_problem()
  def server_connection_timed_out_problem(server, username),
    do: {:server_connection_timed_out, server.ip_address.address, server.ssh_port || 22, username}

  @spec server_connection_refused_problem(Server.t(), String.t()) ::
          Types.server_connection_refused_problem()
  def server_connection_refused_problem(server, username),
    do: {:server_connection_refused, server.ip_address.address, server.ssh_port || 22, username}

  @spec server_fact_gathering_failed_problem(term()) ::
          Types.server_fact_gathering_failed_problem()
  def server_fact_gathering_failed_problem(reason), do: {:server_fact_gathering_failed, reason}

  @spec server_key_exchange_failed_problem(Server.t(), String.t() | nil) ::
          Types.server_key_exchange_failed_problem()
  def server_key_exchange_failed_problem(
        %Server{
          ssh_host_key_fingerprints: ssh_host_key_fingerprints
        },
        unknown_fingerprint
      ),
      do: {:server_key_exchange_failed, unknown_fingerprint, ssh_host_key_fingerprints}

  @spec server_missing_sudo_access_problem(String.t(), String.t()) ::
          Types.server_missing_sudo_access_problem()
  def server_missing_sudo_access_problem(username, stderr),
    do: {:server_missing_sudo_access, username, String.trim(stderr)}

  @spec server_open_ports_check_failed_problem(list({1..65_535, term()})) ::
          Types.server_open_ports_check_failed_problem()
  def server_open_ports_check_failed_problem(port_problems),
    do: {:server_open_ports_check_failed, port_problems}

  @spec server_port_testing_script_failed_problem(:exit, pos_integer(), String.t()) ::
          Types.server_port_testing_script_failed_problem()
  def server_port_testing_script_failed_problem(:exit, exit_code, stderr),
    do: {:server_port_testing_script_failed, {:exit, exit_code, String.trim(stderr)}}

  @spec server_port_testing_script_failed_problem(:error, String.t()) ::
          Types.server_port_testing_script_failed_problem()
  def server_port_testing_script_failed_problem(:error, reason),
    do: {:server_port_testing_script_failed, {:error, reason}}

  @spec server_reconnection_failed_problem(term()) :: Types.server_reconnection_failed_problem()
  def server_reconnection_failed_problem(reason), do: {:server_reconnection_failed, reason}

  @spec server_sudo_access_check_failed_problem(String.t(), term()) ::
          Types.server_sudo_access_check_failed_problem()
  def server_sudo_access_check_failed_problem(username, reason),
    do: {:server_sudo_access_check_failed, username, reason}
end
