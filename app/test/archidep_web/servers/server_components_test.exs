defmodule ArchiDepWeb.Servers.ServerComponentsTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import Hammox
  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias ArchiDep.Helpers.LoadingHelpers
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Servers.ServerComponents
  alias Phoenix.LiveView.JS

  @now ~U[2026-06-27 12:00:00Z]

  # A fingerprint whose parsed human form is deterministic, so the key-exchange
  # problem's rendered fingerprint list can be pinned exactly.
  @sha256_fingerprint "256 SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU root@server (ED25519)"

  setup do
    stub(ArchiDep.Clock.Mock, :now, fn -> @now end)
    :ok
  end

  describe "server_name/1" do
    test "shows the server's name when it has one" do
      server = ServersFactory.build(:server_view, name: "web-01")

      assert rendered_server_name(server) == "web-01"
    end

    test "falls back to the SSH connection description when unnamed" do
      server = ServersFactory.build(:server_view, name: nil)

      assert rendered_server_name(server) == ServerView.ssh_connection_description(server)
    end
  end

  describe "server_card/1 connection states" do
    test "renders the disconnected shape with no real-time state" do
      assert card(server(), state: nil) ==
               base_card(
                 badge: "Not connected",
                 color: :neutral,
                 body: "No connection to this server"
               )
    end

    test "marks an inactive server" do
      assert card(server(active: false), state: nil) ==
               base_card(badge: "Inactive", color: :neutral, body: "No connection to this server")
    end

    test "renders the not-connected state" do
      assert card(server(), state: rts(ServersFactory.random_not_connected_state())) ==
               base_card(
                 badge: "Not connected",
                 color: :neutral,
                 body: "No connection to this server"
               )
    end

    test "renders the connection-pending state" do
      assert card(server(), state: rts(ServersFactory.random_connection_pending_state())) ==
               base_card(badge: "Connection pending", color: :info, body: "Will connect soon")
    end

    test "warns when a pending connection already has a problem" do
      assert card(server(),
               state:
                 rts(ServersFactory.random_connection_pending_state(), problems: [auth_problem()])
             ) ==
               base_card(
                 badge: "Connection pending",
                 color: :warning,
                 body: "Will connect soon",
                 problems: [:error]
               )
    end

    test "renders the connecting state" do
      assert card(server(), state: rts(ServersFactory.random_connecting_state())) ==
               base_card(badge: "Connecting", color: :info, body: "Connecting to the server")
    end

    test "warns when connecting already has a problem" do
      assert card(server(),
               state: rts(ServersFactory.random_connecting_state(), problems: [auth_problem()])
             ) ==
               base_card(
                 badge: "Connecting",
                 color: :warning,
                 body: "Connecting to the server",
                 problems: [:error]
               )
    end

    test "renders the connected state" do
      assert card(server(), state: rts(ServersFactory.random_connected_state())) ==
               base_card(badge: "Connected", color: :success, body: "Connected to the server.")
    end

    test "warns when a connected server has a problem" do
      assert card(server(),
               state: rts(ServersFactory.random_connected_state(), problems: [auth_problem()])
             ) ==
               base_card(
                 badge: "Connected",
                 color: :warning,
                 body: "Connected to the server.",
                 problems: [:error]
               )
    end

    test "renders the reconnecting state" do
      assert card(server(), state: rts(ServersFactory.random_reconnecting_state())) ==
               base_card(badge: "Reconnecting", color: :info, body: "Reconnecting to the server")
    end

    test "renders the disconnected state" do
      assert card(server(), state: rts(ServersFactory.random_disconnected_state())) ==
               base_card(
                 badge: "Disconnected",
                 color: :info,
                 body: "The connection to the server was lost."
               )
    end

    test "warns when a disconnected server has a problem" do
      assert card(server(),
               state: rts(ServersFactory.random_disconnected_state(), problems: [auth_problem()])
             ) ==
               base_card(
                 badge: "Disconnected",
                 color: :warning,
                 body: "The connection to the server was lost.",
                 problems: [:error]
               )
    end

    test "warns when a reconnecting attempt already has a problem" do
      state =
        rts(
          retry_connecting_state(
            connection_pid: self(),
            retrying: %{retry: 0, time: @now, in_seconds: 30, reason: :econnrefused}
          ),
          problems: [auth_problem()]
        )

      assert card(server(), state: state, on_retry_connection: JS.push("retry")) ==
               base_card(
                 badge: "Reconnecting",
                 color: :warning,
                 body: "Server unreachable. Will retry in 30s",
                 problems: [:error],
                 retry: "Retry now"
               )
    end

    test "warns when a re-establishing connection already has a problem" do
      assert card(server(),
               state: rts(ServersFactory.random_reconnecting_state(), problems: [auth_problem()])
             ) ==
               base_card(
                 badge: "Reconnecting",
                 color: :warning,
                 body: "Reconnecting to the server",
                 problems: [:error]
               )
    end

    test "renders the connection-failed state with a retry-connecting action" do
      assert card(server(),
               state: rts(ServersFactory.random_connection_failed_state()),
               on_retry_connection: JS.push("retry")
             ) ==
               base_card(
                 badge: "Connection failed",
                 color: :error,
                 body: "Could not connect to the server.",
                 retry: "Retry connecting"
               )
    end

    test "omits the retry-connecting action without a handler" do
      assert card(server(), state: rts(ServersFactory.random_connection_failed_state())) ==
               base_card(
                 badge: "Connection failed",
                 color: :error,
                 body: "Could not connect to the server."
               )
    end

    test "renders a retry-connecting countdown" do
      state =
        rts(
          retry_connecting_state(
            connection_pid: self(),
            retrying: %{retry: 0, time: @now, in_seconds: 30, reason: :econnrefused}
          )
        )

      assert card(server(), state: state, on_retry_connection: JS.push("retry")) ==
               base_card(
                 badge: "Reconnecting",
                 color: :info,
                 body: "Server unreachable. Will retry in 30s",
                 retry: "Retry now"
               )
    end

    test "shows the attempt count in the countdown for a root user" do
      state =
        rts(
          retry_connecting_state(
            connection_pid: self(),
            retrying: %{retry: 1, time: @now, in_seconds: 30, reason: :timeout}
          )
        )

      assert card(server(), state: state, auth: auth(root: true)) ==
               base_card(
                 badge: "Reconnecting",
                 color: :info,
                 body: "Connection timed out. Will retry in 30s (attempt #2)"
               )
    end
  end

  describe "server_card/1 connected jobs" do
    test "shows the access-check job" do
      assert card(server(),
               state: rts(ServersFactory.random_connected_state(), current_job: :checking_access)
             ) ==
               base_card(
                 badge: "Connected",
                 color: :success,
                 body: "Checking access",
                 busy?: true
               )
    end

    test "shows the app-user setup job" do
      assert card(server(),
               state:
                 rts(ServersFactory.random_connected_state(), current_job: :setting_up_app_user)
             ) ==
               base_card(
                 badge: "Connected",
                 color: :success,
                 body: "Setting up application user",
                 busy?: true
               )
    end

    test "shows the open-ports check job" do
      assert card(server(),
               state:
                 rts(ServersFactory.random_connected_state(), current_job: :checking_open_ports)
             ) ==
               base_card(
                 badge: "Connected",
                 color: :success,
                 body: "Checking open ports",
                 busy?: true
               )
    end

    test "names the setup playbook job" do
      job = {:running_playbook, "setup", "run-1", nil}

      assert card(server(), state: rts(ServersFactory.random_connected_state(), current_job: job)) ==
               base_card(badge: "Connected", color: :success, body: "Setup", busy?: true)
    end

    test "names another playbook job with its ongoing task" do
      job = {:running_playbook, "deploy", "run-1", "Restarting services"}

      assert card(server(), state: rts(ServersFactory.random_connected_state(), current_job: job)) ==
               base_card(
                 badge: "Connected",
                 color: :success,
                 body: "Running deploy: Restarting services",
                 busy?: true
               )
    end

    test "shows a random loading message while gathering facts" do
      result =
        card(server(),
          state: rts(ServersFactory.random_connected_state(), current_job: :gathering_facts)
        )

      assert result.body in LoadingHelpers.loading_messages()

      assert %{result | body: :loading} ==
               base_card(badge: "Connected", color: :success, body: :loading, busy?: true)
    end
  end

  describe "server_card/1 problems and actions" do
    test "renders every problem while colouring the card by the filtered set" do
      state =
        rts(ServersFactory.random_connected_state(),
          problems: [auth_problem(), refused_problem()]
        )

      assert card(server(), state: state) ==
               base_card(
                 badge: "Connected",
                 color: :warning,
                 body: "Connected to the server.",
                 problems: [:error, :warning]
               )
    end

    test "keeps a post-setup timeout problem visible but does not let it colour the card" do
      state =
        rts(ServersFactory.random_connected_state(),
          set_up_at: @now,
          problems: [timeout_problem()]
        )

      assert card(server(set_up_at: @now), state: state) ==
               base_card(
                 badge: "Connected",
                 color: :success,
                 body: "Connected to the server.",
                 problems: [:warning]
               )
    end

    test "lets a timeout problem colour the card before setup" do
      state = rts(ServersFactory.random_connecting_state(), problems: [timeout_problem()])

      assert card(server(), state: state) ==
               base_card(
                 badge: "Connecting",
                 color: :warning,
                 body: "Connecting to the server",
                 problems: [:warning]
               )
    end

    test "offers an edit action when editing is enabled" do
      assert card(server(),
               state: rts(ServersFactory.random_connected_state()),
               edit_enabled: true,
               on_edit: JS.push("edit")
             ) ==
               base_card(
                 badge: "Connected",
                 color: :success,
                 body: "Connected to the server.",
                 edit?: true
               )
    end

    test "offers a details link when a details path is given" do
      assert card(server(),
               state: rts(ServersFactory.random_connected_state()),
               details_link: "/servers/42"
             ) ==
               base_card(
                 badge: "Connected",
                 color: :success,
                 body: "Connected to the server.",
                 details?: true
               )
    end
  end

  describe "admin_server_card/1" do
    test "renders the disconnected shape with no real-time state" do
      assert admin_card(admin_server(), state: nil) ==
               base_admin(short_status: "n/a", body: "No connection to this server")
    end

    test "marks an inactive server" do
      assert admin_card(admin_server(active: false), state: nil) ==
               base_admin(short_status: "inactive", body: "No connection to this server")
    end

    test "renders the not-connected state" do
      assert admin_card(admin_server(), state: rts(ServersFactory.random_not_connected_state())) ==
               base_admin(short_status: "n/a", body: "No connection to this server")
    end

    test "renders the connection-pending state" do
      assert admin_card(admin_server(),
               state: rts(ServersFactory.random_connection_pending_state())
             ) ==
               base_admin(short_status: "pending", body: "Will connect soon")
    end

    test "renders the connecting state" do
      assert admin_card(admin_server(), state: rts(ServersFactory.random_connecting_state())) ==
               base_admin(short_status: "connecting", body: "Connecting to the server")
    end

    test "renders the connected state" do
      assert admin_card(admin_server(), state: rts(ServersFactory.random_connected_state())) ==
               base_admin(short_status: "connected", body: "Connected to the server.")
    end

    test "renders the reconnecting state" do
      assert admin_card(admin_server(), state: rts(ServersFactory.random_reconnecting_state())) ==
               base_admin(short_status: "reconnecting", body: "Reconnecting to the server")
    end

    test "renders the connection-failed state" do
      assert admin_card(admin_server(),
               state: rts(ServersFactory.random_connection_failed_state())
             ) ==
               base_admin(short_status: "conn. failed", body: "Could not connect to the server.")
    end

    test "renders the disconnected state" do
      assert admin_card(admin_server(), state: rts(ServersFactory.random_disconnected_state())) ==
               base_admin(
                 short_status: "conn. lost",
                 body: "The connection to the server was lost."
               )
    end

    test "shows the access-check job" do
      assert admin_card(admin_server(),
               state: rts(ServersFactory.random_connected_state(), current_job: :checking_access)
             ) ==
               base_admin(short_status: "sudo", body: "Checking access", busy?: true)
    end

    test "shows the open-ports check job" do
      assert admin_card(admin_server(),
               state:
                 rts(ServersFactory.random_connected_state(), current_job: :checking_open_ports)
             ) ==
               base_admin(short_status: "ports", body: "Checking open ports", busy?: true)
    end

    test "names a running playbook job" do
      job = {:running_playbook, "deploy", "run-1", "Restarting services"}

      assert admin_card(admin_server(),
               state: rts(ServersFactory.random_connected_state(), current_job: job)
             ) ==
               base_admin(
                 short_status: "deploy",
                 body: "Running deploy: Restarting services",
                 busy?: true
               )
    end

    test "shows the facts job with a random loading message" do
      result =
        admin_card(admin_server(),
          state: rts(ServersFactory.random_connected_state(), current_job: :gathering_facts)
        )

      assert result.body in LoadingHelpers.loading_messages()

      assert %{result | body: :loading} ==
               base_admin(short_status: "facts", body: :loading, busy?: true)
    end

    test "renders a retry-connecting countdown" do
      state =
        rts(
          retry_connecting_state(
            connection_pid: self(),
            retrying: %{retry: 0, time: @now, in_seconds: 30, reason: :econnrefused}
          )
        )

      assert admin_card(admin_server(), state: state) ==
               base_admin(
                 short_status: "retry 30s",
                 body: "Server unreachable. Will retry in 30s"
               )
    end

    test "shows the attempt count in the countdown for a root user" do
      state =
        rts(
          retry_connecting_state(
            connection_pid: self(),
            retrying: %{retry: 0, time: @now, in_seconds: 30, reason: :econnrefused}
          )
        )

      assert admin_card(admin_server(), state: state, auth: auth(root: true)) ==
               base_admin(
                 short_status: "retry 30s (#1)",
                 body: "Server unreachable. Will retry in 30s (attempt #1)"
               )
    end
  end

  describe "server_owner_name/1" do
    test "prefers the group member's username" do
      member = ServersFactory.build(:server_group_member, username: "alice")
      owner = ServersFactory.build(:server_owner, root: false, group_member: member)
      server = ServersFactory.build(:server_view, owner: owner)

      assert ServerComponents.server_owner_name(server) == "alice"
    end

    test "falls back to the owner's own username" do
      owner = ServersFactory.build(:server_owner, root: true, group_member: nil, username: "bob")
      server = ServersFactory.build(:server_view, owner: owner)

      assert ServerComponents.server_owner_name(server) == "bob"
    end

    test "falls back to the server's connection username" do
      owner = ServersFactory.build(:server_owner, root: true, group_member: nil, username: nil)
      server = ServersFactory.build(:server_view, owner: owner, username: "carol")

      assert ServerComponents.server_owner_name(server) == "carol"
    end
  end

  describe "server_problem/1 connection problems" do
    test "reports an authentication failure for the connection username" do
      assert problem({:server_authentication_failed, :username, "deployer"}) ==
               %{severity: :error, text: "Authentication failed for user deployer", retry: nil}
    end

    test "reports an application-user authentication failure to a root user" do
      assert problem({:server_authentication_failed, :app_username, "archidep"},
               auth: auth(root: true)
             ) ==
               %{
                 severity: :error,
                 text: "Authentication failed for application user archidep",
                 retry: nil
               }
    end

    test "hides the application user from a non-root user on authentication failure" do
      assert problem({:server_authentication_failed, :app_username, "archidep"}) ==
               %{severity: :error, text: "Authentication failed", retry: nil}
    end

    test "reports a refused connection on the default SSH port" do
      assert problem({:server_connection_refused, {1, 2, 3, 4}, 22, "deployer"}) ==
               %{severity: :warning, text: "Connection refused to deployer@1.2.3.4", retry: nil}
    end

    test "reports a refused connection on a custom SSH port" do
      assert problem({:server_connection_refused, {1, 2, 3, 4}, 2222, "deployer"}) ==
               %{
                 severity: :warning,
                 text: "Connection refused to deployer@1.2.3.4:2222",
                 retry: nil
               }
    end

    test "reports a timed-out connection on the default SSH port" do
      assert problem({:server_connection_timed_out, {1, 2, 3, 4}, 22, "deployer"}) ==
               %{
                 severity: :warning,
                 text: "Timeout when connecting to deployer@1.2.3.4",
                 retry: nil
               }
    end

    test "reports a timed-out connection on a custom SSH port" do
      assert problem({:server_connection_timed_out, {1, 2, 3, 4}, 2222, "deployer"}) ==
               %{
                 severity: :warning,
                 text: "Timeout when connecting to deployer@1.2.3.4:2222",
                 retry: nil
               }
    end
  end

  describe "server_problem/1 access problems" do
    test "reports missing sudo access, hiding stderr from a non-root user" do
      assert problem({:server_missing_sudo_access, "deployer", "no sudo for you"}) ==
               %{severity: :error, text: "User deployer does not have sudo access", retry: nil}
    end

    test "reports missing sudo access with stderr for a root user" do
      assert problem({:server_missing_sudo_access, "deployer", "no sudo for you"},
               auth: auth(root: true)
             ) ==
               %{
                 severity: :error,
                 text: "User deployer does not have sudo access \"no sudo for you\"",
                 retry: nil
               }
    end

    test "reports a sudo-access check failure, hiding the reason from a non-root user" do
      assert problem({:server_sudo_access_check_failed, "deployer", :timeout}) ==
               %{
                 severity: :error,
                 text: "Could not check whether deployer has sudo access",
                 retry: nil
               }
    end

    test "reports a sudo-access check failure with the reason for a root user" do
      assert problem({:server_sudo_access_check_failed, "deployer", :timeout},
               auth: auth(root: true)
             ) ==
               %{
                 severity: :error,
                 text: "Could not check whether deployer has sudo access :timeout",
                 retry: nil
               }
    end
  end

  describe "server_problem/1 operation problems" do
    test "reports a fact-gathering failure, hiding the reason from a non-root user" do
      assert problem({:server_fact_gathering_failed, "boom"}) ==
               %{severity: :warning, text: "Could not gather facts from the server", retry: nil}
    end

    test "reports a fact-gathering failure with the reason for a root user" do
      assert problem({:server_fact_gathering_failed, "boom"}, auth: auth(root: true)) ==
               %{
                 severity: :warning,
                 text: "Could not gather facts from the server \"boom\"",
                 retry: nil
               }
    end

    test "reports a port-testing script failure, hiding the reason from a non-root user" do
      assert problem({:server_port_testing_script_failed, {:error, "boom"}}) ==
               %{severity: :warning, text: "Could not check open ports on the server", retry: nil}
    end

    test "reports a port-testing script failure with the reason for a root user" do
      assert problem({:server_port_testing_script_failed, {:error, "boom"}},
               auth: auth(root: true)
             ) ==
               %{
                 severity: :warning,
                 text: "Could not check open ports on the server {:error, \"boom\"}",
                 retry: nil
               }
    end

    test "reports a reconnection failure, hiding the reason from a non-root user" do
      assert problem({:server_reconnection_failed, :nxdomain}) ==
               %{severity: :error, text: "Could not reconnect to server after setup", retry: nil}
    end

    test "reports a reconnection failure with the reason for a root user" do
      assert problem({:server_reconnection_failed, :nxdomain}, auth: auth(root: true)) ==
               %{
                 severity: :error,
                 text: "Could not reconnect to server after setup :nxdomain",
                 retry: nil
               }
    end

    test "reports an unexpected problem, hiding its detail from a non-root user" do
      assert problem({:something_unexpected, 42}) ==
               %{severity: :error, text: "Oops, an unexpected problem occurred", retry: nil}
    end

    test "reports an unexpected problem with its detail for a root user" do
      assert problem({:something_unexpected, 42}, auth: auth(root: true)) ==
               %{
                 severity: :error,
                 text: "Oops, an unexpected problem occurred {:something_unexpected, 42}",
                 retry: nil
               }
    end
  end

  describe "server_problem/1 ansible playbook failures" do
    test "reports a failed playbook to a root user with a retry action" do
      problem = {:server_ansible_playbook_failed, "setup", :failed, ansible_stats(failures: 2)}

      assert problem(problem,
               auth: auth(root: true),
               connected: true,
               on_retry_operation: JS.push("retry")
             ) ==
               %{
                 severity: :error,
                 text: "Ansible playbook setup failed with state :failed (2 tasks failed)",
                 retry: :idle
               }
    end

    test "summarises a single failure and an unreachable host" do
      problem =
        {:server_ansible_playbook_failed, "setup", :failed,
         ansible_stats(failures: 1, unreachable: 1)}

      assert problem(problem, auth: auth(root: true)) ==
               %{
                 severity: :error,
                 text:
                   "Ansible playbook setup failed with state :failed (1 task failed, host unreachable)",
                 retry: nil
               }
    end

    test "omits the detail when there is nothing to summarise" do
      problem = {:server_ansible_playbook_failed, "setup", :failed, ansible_stats()}

      assert problem(problem, auth: auth(root: true)) ==
               %{
                 severity: :error,
                 text: "Ansible playbook setup failed with state :failed",
                 retry: nil
               }
    end

    test "spins the retry action while the failed playbook re-runs" do
      problem = {:server_ansible_playbook_failed, "setup", :failed, ansible_stats(failures: 2)}

      assert problem(problem,
               auth: auth(root: true),
               connected: true,
               current_job: {:running_playbook, "setup", "run-1", nil},
               on_retry_operation: JS.push("retry")
             ) ==
               %{
                 severity: :error,
                 text: "Ansible playbook setup failed with state :failed (2 tasks failed)",
                 retry: :retrying
               }
    end

    test "reports a generic provisioning failure to a non-root user without a retry action" do
      problem = {:server_ansible_playbook_failed, "setup", :failed, ansible_stats(failures: 2)}

      assert problem(problem, connected: true, on_retry_operation: JS.push("retry")) ==
               %{severity: :error, text: "setup provisioning task failed", retry: nil}
    end
  end

  describe "server_problem/1 open-ports failures" do
    test "lists the unreachable ports with a retry action for a root user" do
      problem =
        {:server_open_ports_check_failed,
         [
           {8080, %Req.TransportError{reason: :econnrefused}},
           {9090, %Req.TransportError{reason: :timeout}},
           {7070, :boom}
         ]}

      assert problem(problem,
               auth: auth(root: true),
               connected: true,
               on_retry_operation: JS.push("retry")
             ) ==
               %{
                 severity: :warning,
                 text:
                   "The following ports might not be open: Port 8,080: connection refused Port 9,090: connection timeout Port 7,070: error :boom",
                 retry: :idle
               }
    end

    test "hides the unexpected reason from a non-root user" do
      problem = {:server_open_ports_check_failed, [{7070, :boom}]}

      assert problem(problem) ==
               %{
                 severity: :warning,
                 text: "The following ports might not be open: Port 7,070: error",
                 retry: nil
               }
    end
  end

  describe "server_problem/1 expected property mismatches" do
    test "reports a hostname mismatch" do
      assert mismatch(:hostname, "web", "db") ==
               %{
                 severity: :warning,
                 text: "Server hostname is db when it should be web",
                 retry: nil
               }
    end

    test "reports a CPU count mismatch" do
      assert mismatch(:cpus, 4, 2) ==
               %{severity: :warning, text: "Server has 2 CPUs when it should have 4", retry: nil}
    end

    test "reports a CPU core mismatch in the singular" do
      assert mismatch(:cores, 4, 1) ==
               %{
                 severity: :warning,
                 text: "Server has 1 CPU core when it should have 4",
                 retry: nil
               }
    end

    test "reports a vCPU mismatch" do
      assert mismatch(:vcpus, 4, 2) ==
               %{severity: :warning, text: "Server has 2 vCPUs when it should have 4", retry: nil}
    end

    test "reports a memory mismatch" do
      assert mismatch(:memory, 2048, 1024) ==
               %{
                 severity: :warning,
                 text: "Server has 1,024 MB of RAM when it should have 2,048",
                 retry: nil
               }
    end

    test "reports a swap mismatch" do
      assert mismatch(:swap, 1024, 0) ==
               %{
                 severity: :warning,
                 text: "Server has 0 MB of swap when it should have 1,024",
                 retry: nil
               }
    end

    test "reports a system-type mismatch" do
      assert mismatch(:system, "linux", "windows") ==
               %{
                 severity: :warning,
                 text: "Server is running a system of type windows when it should be linux",
                 retry: nil
               }
    end

    test "reports an architecture mismatch" do
      assert mismatch(:architecture, "x86_64", "arm64") ==
               %{
                 severity: :warning,
                 text: "Server is running on architecture arm64 when it should be x86_64",
                 retry: nil
               }
    end

    test "reports an OS family mismatch" do
      assert mismatch(:os_family, "Debian", "RedHat") ==
               %{
                 severity: :warning,
                 text:
                   "Server is running an operating system of the RedHat family when it should be Debian",
                 retry: nil
               }
    end

    test "reports a distribution mismatch" do
      assert mismatch(:distribution, "Ubuntu", "Fedora") ==
               %{
                 severity: :warning,
                 text: "Server is running the Fedora Linux distribution when it should be Ubuntu",
                 retry: nil
               }
    end

    test "reports a distribution-release mismatch" do
      assert mismatch(:distribution_release, "jammy", "focal") ==
               %{
                 severity: :warning,
                 text: "Server is running distribution release focal when it should be jammy",
                 retry: nil
               }
    end

    test "reports a distribution-version mismatch" do
      assert mismatch(:distribution_version, "22.04", "20.04") ==
               %{
                 severity: :warning,
                 text: "Server is running distribution version 20.04 when it should be 22.04",
                 retry: nil
               }
    end

    test "reports any other property mismatch generically" do
      assert mismatch(:kernel, "6.1", "5.4") ==
               %{
                 severity: :warning,
                 text: "Server property kernel has value 5.4 when it should be 6.1",
                 retry: nil
               }
    end
  end

  describe "server_problem/1 key exchange failures" do
    test "lists the registered fingerprints when the server presents an unknown one" do
      problem = {:server_key_exchange_failed, "AA:BB:CC", @sha256_fingerprint}

      assert problem(problem) == %{
               severity: :error,
               text:
                 "SSH key exchange failed The host key fingerprint provided by the server is: AA:BB:CC The following host key fingerprints are registered for this server: SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU (ED25519)",
               retry: nil
             }
    end

    test "reports that no fingerprints are registered" do
      problem = {:server_key_exchange_failed, nil, ""}

      assert problem(problem) == %{
               severity: :error,
               text:
                 "SSH key exchange failed Server host key fingerprint is unknown No known host key fingerprints were registered",
               retry: nil
             }
    end

    test "lists invalid registered fingerprints" do
      problem = {:server_key_exchange_failed, [], "not-a-fingerprint"}

      assert problem(problem) == %{
               severity: :error,
               text:
                 "SSH key exchange failed The following invalid host key fingerprints are registered for this server: not-a-fingerprint",
               retry: nil
             }
    end
  end

  defp rendered_server_name(server) do
    html = render_component(&ServerComponents.server_name/1, server: server)
    normalized_text(html)
  end

  defp server(opts \\ []),
    do:
      ServersFactory.build(
        :server_view,
        Keyword.merge([name: "web-01", active: true, set_up_at: nil], opts)
      )

  defp admin_server(opts \\ []) do
    member = ServersFactory.build(:server_group_member, username: "alice")
    owner = ServersFactory.build(:server_owner, root: false, group_member: member)

    ServersFactory.build(
      :server_view,
      Keyword.merge(
        [
          owner: owner,
          username: "deployer",
          ip_address: %Postgrex.INET{address: {192, 168, 1, 10}, netmask: nil},
          ssh_port: nil,
          active: true,
          set_up_at: nil
        ],
        opts
      )
    )
  end

  defp auth(opts \\ []), do: Factory.build(:authentication, Keyword.merge([root: false], opts))

  defp card(server, opts) do
    html =
      render_component(&ServerComponents.server_card/1,
        auth: Keyword.get_lazy(opts, :auth, &auth/0),
        server: server,
        state: Keyword.get(opts, :state),
        class: nil,
        details_link: Keyword.get(opts, :details_link),
        edit_enabled: Keyword.get(opts, :edit_enabled, false),
        on_edit: Keyword.get(opts, :on_edit),
        on_retry_connection: Keyword.get(opts, :on_retry_connection),
        on_retry_operation: Keyword.get(opts, :on_retry_operation)
      )

    [card] = find_html_elements(html, ".card")
    [_title, body_row | _rest] = find_html_elements(card, ".card-body > div")

    %{
      name: card |> find_html_elements(".card-title > div") |> List.first() |> normalized_text(),
      badge:
        card |> find_html_elements(".card-title .badge") |> List.first() |> normalized_text(),
      color: color(card),
      busy?: find_html_elements(card, "svg.animate-spin") != [],
      body: body_row |> find_html_elements("span") |> List.first() |> normalized_text(),
      problems: card |> find_html_elements("[role=alert]") |> Enum.map(&severity/1),
      retry: card |> find_html_elements(".card-actions .btn-secondary") |> retry_text(),
      edit?: find_html_elements(card, ".card-actions .btn-primary") != [],
      details?: find_html_elements(card, ".card-actions a.btn-info") != []
    }
  end

  defp base_card(opts),
    do: %{
      name: Keyword.get(opts, :name, "web-01"),
      badge: Keyword.fetch!(opts, :badge),
      color: Keyword.fetch!(opts, :color),
      busy?: Keyword.get(opts, :busy?, false),
      body: Keyword.fetch!(opts, :body),
      problems: Keyword.get(opts, :problems, []),
      retry: Keyword.get(opts, :retry),
      edit?: Keyword.get(opts, :edit?, false),
      details?: Keyword.get(opts, :details?, false)
    }

  defp admin_card(server, opts) do
    html =
      render_component(&ServerComponents.admin_server_card/1,
        auth: Keyword.get_lazy(opts, :auth, &auth/0),
        server: server,
        state: Keyword.get(opts, :state),
        class: nil,
        details_link: "/servers/#{server.id}"
      )

    [card] = find_html_elements(html, ".card")
    [owner_div, status_div] = find_html_elements(card, ".card-title > div")

    %{
      owner: outer_text(owner_div),
      conn:
        owner_div |> find_html_elements(".tooltip-content") |> List.first() |> normalized_text(),
      short_status: outer_text(status_div),
      body:
        status_div |> find_html_elements(".tooltip-content") |> List.first() |> normalized_text(),
      busy?: find_html_elements(card, "svg.animate-spin") != []
    }
  end

  defp base_admin(opts),
    do: %{
      owner: "alice",
      conn: "deployer@192.168.1.10",
      short_status: Keyword.fetch!(opts, :short_status),
      body: Keyword.fetch!(opts, :body),
      busy?: Keyword.get(opts, :busy?, false)
    }

  defp problem(problem, opts \\ []) do
    html =
      render_component(&ServerComponents.server_problem/1,
        auth: Keyword.get_lazy(opts, :auth, &auth/0),
        problem: problem,
        connected: Keyword.get(opts, :connected, false),
        current_job: Keyword.get(opts, :current_job),
        on_retry_operation: Keyword.get(opts, :on_retry_operation)
      )

    [alert] = find_html_elements(html, "[role=alert]")

    %{
      severity: severity(alert),
      text: text_excluding(alert, "button"),
      retry: retry_state(alert)
    }
  end

  defp retry_state(alert) do
    case find_html_elements(alert, "button") do
      [] ->
        nil

      [button | _rest] ->
        if find_html_elements(button, "svg.animate-spin") != [], do: :retrying, else: :idle
    end
  end

  defp mismatch(property, expected, actual) do
    problem({:server_expected_property_mismatch, property, expected, actual})
  end

  defp ansible_stats(opts \\ []),
    do: %{
      changed: 0,
      failures: Keyword.get(opts, :failures, 0),
      ignored: 0,
      ok: 0,
      rescued: 0,
      skipped: 0,
      unreachable: Keyword.get(opts, :unreachable, 0)
    }

  defp rts(connection_state, opts \\ []),
    do: %ServerRealTimeState{
      connection_state: connection_state,
      name: "web-01",
      conn_params: {{127, 0, 0, 1}, 22, "deployer"},
      username: "deployer",
      app_username: "archidep",
      set_up_at: Keyword.get(opts, :set_up_at),
      current_job: Keyword.get(opts, :current_job),
      problems: Keyword.get(opts, :problems, []),
      version: 1
    }

  defp auth_problem, do: {:server_authentication_failed, :username, "deployer"}
  defp refused_problem, do: {:server_connection_refused, {1, 2, 3, 4}, 22, "deployer"}
  defp timeout_problem, do: {:server_connection_timed_out, {1, 2, 3, 4}, 22, "deployer"}

  defp color(card) do
    classes = card |> html_element_attribute("class") |> String.split()

    cond do
      "bg-success" in classes -> :success
      "bg-error" in classes -> :error
      "bg-warning" in classes -> :warning
      "bg-info" in classes -> :info
      "bg-neutral" in classes -> :neutral
    end
  end

  defp severity(alert) do
    classes = alert |> html_element_attribute("class") |> String.split()

    cond do
      "alert-error" in classes -> :error
      "alert-warning" in classes -> :warning
    end
  end

  defp retry_text([]), do: nil
  defp retry_text([button | _rest]), do: normalized_text(button)

  defp outer_text(element) do
    inner =
      element
      |> find_html_elements(".tooltip-content")
      |> Enum.map_join(" ", &html_element_text/1)

    strip(html_element_text(element), inner)
  end

  defp text_excluding(element, selector) do
    inner = element |> find_html_elements(selector) |> Enum.map_join(" ", &html_element_text/1)
    strip(html_element_text(element), inner)
  end

  defp strip(full, ""), do: full |> String.split() |> Enum.join(" ")

  defp strip(full, inner),
    do: full |> String.replace(inner, "") |> String.split() |> Enum.join(" ")

  defp normalized_text(element),
    do: element |> html_element_text() |> String.split() |> Enum.join(" ")
end
