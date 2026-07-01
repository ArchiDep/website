defmodule ArchiDep.Servers.ServerTracking.ServerProblemsTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.ServerTracking.ServerProblems
  alias ArchiDep.Support.ServersFactory

  describe "problem constructors" do
    test "an ansible playbook failed problem carries the playbook, state and stats" do
      run = ServersFactory.build(:ansible_playbook_run, state: :failed)

      assert ServerProblems.server_ansible_playbook_failed_problem(run) ==
               {:server_ansible_playbook_failed, run.playbook, run.state,
                AnsiblePlaybookRun.stats(run)}
    end

    test "an ansible playbook repeatedly failed problem carries each run's playbook, state and stats" do
      runs = [
        ServersFactory.build(:ansible_playbook_run, state: :failed),
        ServersFactory.build(:ansible_playbook_run, state: :timeout)
      ]

      assert ServerProblems.server_ansible_playbook_repeatedly_failed_problem(runs) ==
               {:server_ansible_playbook_repeatedly_failed,
                Enum.map(runs, &{&1.playbook, &1.state, AnsiblePlaybookRun.stats(&1)})}
    end

    test "an authentication failed problem for the application username is tagged :app_username" do
      server = ServersFactory.build(:server)

      assert ServerProblems.server_authentication_failed_problem(server, server.app_username) ==
               {:server_authentication_failed, :app_username, server.app_username}
    end

    test "an authentication failed problem for any other username is tagged :username" do
      server = ServersFactory.build(:server, app_username: "appuser")

      assert ServerProblems.server_authentication_failed_problem(server, "someone") ==
               {:server_authentication_failed, :username, "someone"}
    end

    test "a connection timed out problem carries the server's address, port and username" do
      server = ServersFactory.build(:server, ssh_port: 2222)

      assert ServerProblems.server_connection_timed_out_problem(server, "root") ==
               {:server_connection_timed_out, server.ip_address.address, 2222, "root"}
    end

    test "a connection timed out problem defaults to port 22 when the server has no SSH port" do
      server = ServersFactory.build(:server, ssh_port: nil)

      assert ServerProblems.server_connection_timed_out_problem(server, "root") ==
               {:server_connection_timed_out, server.ip_address.address, 22, "root"}
    end

    test "a connection refused problem carries the server's address, port and username" do
      server = ServersFactory.build(:server, ssh_port: 2222)

      assert ServerProblems.server_connection_refused_problem(server, "root") ==
               {:server_connection_refused, server.ip_address.address, 2222, "root"}
    end

    test "a connection refused problem defaults to port 22 when the server has no SSH port" do
      server = ServersFactory.build(:server, ssh_port: nil)

      assert ServerProblems.server_connection_refused_problem(server, "root") ==
               {:server_connection_refused, server.ip_address.address, 22, "root"}
    end

    test "a fact gathering failed problem carries its reason" do
      assert ServerProblems.server_fact_gathering_failed_problem(:enoent) ==
               {:server_fact_gathering_failed, :enoent}
    end

    test "a key exchange failed problem carries the unknown fingerprint and the server's fingerprints" do
      server = ServersFactory.build(:server)

      assert ServerProblems.server_key_exchange_failed_problem(server, "SHA256:unknown") ==
               {:server_key_exchange_failed, "SHA256:unknown", server.ssh_host_key_fingerprints}
    end

    test "a key exchange failed problem accepts a nil unknown fingerprint" do
      server = ServersFactory.build(:server)

      assert ServerProblems.server_key_exchange_failed_problem(server, nil) ==
               {:server_key_exchange_failed, nil, server.ssh_host_key_fingerprints}
    end

    test "a missing sudo access problem trims the standard error output" do
      assert ServerProblems.server_missing_sudo_access_problem("root", "  denied\n") ==
               {:server_missing_sudo_access, "root", "denied"}
    end

    test "an open ports check failed problem carries the per-port problems" do
      port_problems = [{80, :closed}, {443, :timeout}]

      assert ServerProblems.server_open_ports_check_failed_problem(port_problems) ==
               {:server_open_ports_check_failed, port_problems}
    end

    test "a port testing script failed problem for an exit carries the code and trimmed stderr" do
      assert ServerProblems.server_port_testing_script_failed_problem(:exit, 2, "  boom\n") ==
               {:server_port_testing_script_failed, {:exit, 2, "boom"}}
    end

    test "a port testing script failed problem for an error carries its reason" do
      assert ServerProblems.server_port_testing_script_failed_problem(:error, :closed) ==
               {:server_port_testing_script_failed, {:error, :closed}}
    end

    test "a reconnection failed problem carries its reason" do
      assert ServerProblems.server_reconnection_failed_problem(:econnrefused) ==
               {:server_reconnection_failed, :econnrefused}
    end

    test "a sudo access check failed problem carries the username and reason" do
      assert ServerProblems.server_sudo_access_check_failed_problem("root", :timeout) ==
               {:server_sudo_access_check_failed, "root", :timeout}
    end
  end

  describe "problem predicates" do
    @sample_problems [
      {:server_key_exchange_failed, "SHA256:unknown", "fingerprints"},
      {:server_ansible_playbook_failed, "setup", :failed, %{}},
      {:server_expected_property_mismatch, :hostname, "expected", "actual"},
      {:server_connection_refused, {127, 0, 0, 1}, 22, "root"}
    ]

    # Each predicate is asserted by applying it to the whole sample set and
    # pinning the exact list of classifications, so a predicate matching the
    # wrong problem kind fails the equality.
    defp classify(predicate), do: Enum.map(@sample_problems, predicate)

    test "server_problem?/1 matches any problem whose type is in the given list" do
      predicate =
        ServerProblems.server_problem?([:server_key_exchange_failed, :server_connection_refused])

      assert classify(predicate) == [true, false, false, true]
    end

    test "server_problem?/1 matches a problem of a single given type" do
      predicate = ServerProblems.server_problem?(:server_ansible_playbook_failed)

      assert classify(predicate) == [false, true, false, false]
    end

    test "server_ansible_playbook_failed_problem?/1 matches a failed run of the given playbook" do
      predicate = ServerProblems.server_ansible_playbook_failed_problem?("setup")

      assert classify(predicate) == [false, true, false, false]
    end

    test "server_ansible_playbook_failed_problem?/1 does not match a failed run of another playbook" do
      predicate = ServerProblems.server_ansible_playbook_failed_problem?("teardown")

      assert classify(predicate) == [false, false, false, false]
    end

    test "server_key_exchange_failed_problem?/0 matches a key exchange failure" do
      predicate = ServerProblems.server_key_exchange_failed_problem?()

      assert classify(predicate) == [true, false, false, false]
    end

    test "server_expected_property_mismatch_problem?/1 matches a mismatch of the given property" do
      predicate = ServerProblems.server_expected_property_mismatch_problem?(:hostname)

      assert classify(predicate) == [false, false, true, false]
    end

    test "server_expected_property_mismatch_problem?/1 does not match a mismatch of another property" do
      predicate = ServerProblems.server_expected_property_mismatch_problem?(:memory)

      assert classify(predicate) == [false, false, false, false]
    end

    test "server_expected_property_mismatch_problem?/1 accepts a predicate over the property" do
      predicate =
        ServerProblems.server_expected_property_mismatch_problem?(&(&1 == :hostname))

      assert classify(predicate) == [false, false, true, false]
    end
  end
end
