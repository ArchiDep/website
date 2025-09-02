defmodule ArchiDep.Servers.ServerTracking.ServerManagerTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.FactoryHelpers, only: [bool: 0]
  import Hammox
  alias ArchiDep.Http
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerConnection
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias ArchiDep.Servers.ServerTracking.ServerManagerMock
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.GenServerProxy
  alias ArchiDep.Support.NoOpGenServer
  alias ArchiDep.Support.ServersFactory
  alias Req.Response

  defmodule FakeHttpError do
    defexception [:message]
  end

  setup :verify_on_exit!

  setup %{test: test} do
    test_pid = self()

    state_factory = fn ->
      allow(Ansible.Mock, test_pid, self())
      allow(Http.Mock, test_pid, self())
      allow(ServerManagerMock, test_pid, self())
      ServerManagerMock
    end

    server = ServersFactory.build(:server, set_up_at: nil)
    server_opts = [state: state_factory]

    initialize_fn = fn actions ->
      initialize_server_manager(server, server_opts, test, actions)
    end

    {:ok, initialize: initialize_fn, pid: test_pid, server: server}
  end

  test "a server manager is a significant transient process", %{server: server, test: test} do
    opts = [value: Faker.random_between(1, 1_000_000)]

    assert %{
             restart: :transient,
             significant: true
           } = ServerManager.child_spec({server.id, test, opts})
  end

  test "initialize a server manager", %{initialize: initialize} do
    initialize.([])
  end

  test "cancel a timer when starting a server manager", %{
    initialize: initialize,
    pid: test_pid
  } do
    # Start a timer to cancel before the end of this test.
    timer_ref = Process.send_after(self(), :timer, 5000)
    timer_remaining = Process.read_timer(timer_ref)
    assert is_integer(timer_remaining) and timer_remaining > 4000

    # Expect that the server manager will receive a done message at some point.
    # When it does, send a done message to the test process so that we know the
    # test is complete.
    expect(ServerManagerMock, :on_message, fn state, :done ->
      send(test_pid, :done)
      state
    end)

    # Initialize the server manager with a timer cancelation action and an
    # action that sends a done message.
    initialize.([cancel_timer(timer_ref), send_message(:done)])

    # Wait for the done message.
    assert_receive :done, 500
    refute_received _anything_else

    # Ensure the timer has been canceled.
    assert Process.read_timer(timer_ref) == false
  end

  test "have a server manager open a connection to its server", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    # Prepare the fake connection parameters.
    host = server.ip_address.address
    port = server.ssh_port || 22
    username = server.username
    server_conn = ServerConnection.name(server)

    # Start a fake server connection process that will forward all calls to the
    # test process.
    start_link_supervised!(%{
      id: ServerConnection,
      start: {GenServerProxy, :start_link, [self(), server_conn]}
    })

    # Expected the server manager to handle the connection task result at some
    # point. Forward the result to the test process when that happens.
    expect(ServerManagerMock, :handle_task_result, fn state, ref, result ->
      send(test_pid, {:task_result, ref, result})
      state
    end)

    # Initialize the server manager with a connection action.
    initialize.([connect(host, port, username)])

    # Wait for the message indicating that the faker server connection has
    # received and forwarded the connection call.
    assert_receive {:proxy, ^server_conn,
                    {:call, {:connect, ^host, ^port, ^username, silently_accept_hosts: true},
                     from}},
                   500

    # Ensure that the server manager has called the connection function.
    assert_receive {:connect_task, connect_task}, 500
    refute_received _anything_else

    # Simulate a successful reply from the fake server connection.
    connection_ref = make_ref()
    GenServer.reply(from, {:ok, connection_ref})

    # Ensure that the server manager has received the connection task result.
    connect_task_ref = connect_task.ref
    assert_receive {:task_result, ^connect_task_ref, {:ok, ^connection_ref}}, 500
    refute_received _anything_else
  end

  test "have a server manager monitor another process", %{
    initialize: initialize,
    test_pid: test_pid
  } do
    # Start another process that will be monitored by the server manager.
    pid = start_supervised!(NoOpGenServer)

    # Expect the server manager to receive a connection crashed message when the
    # monitored process crashes. Send a :done message to the test process when
    # that happens, marking the end of the test.
    expect(ServerManagerMock, :connection_crashed, fn state, ^pid, :oops ->
      send(test_pid, :done)
      state
    end)

    # Have the server manager forward the :started message to the test process.
    # We use this message to know when the server manager has finished
    # initializing, before we simulate the crash of the monitored process.
    expect(ServerManagerMock, :on_message, fn state, :started ->
      send(test_pid, :started)
      state
    end)

    # Initialize the server manager, have it monitor the other process, and wait
    # for it to finish initializing.
    initialize.([monitor(pid), send_message(:started)])
    assert_receive :started, 500

    # Simulate a crash of the monitored process.
    Process.exit(pid, :oops)

    # Ensure that the server manager has received the crash message.
    assert_receive :done, 500
  end

  test "have a server manager demonitor a task", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    assert test_server_manager!(
             initialize,
             test_pid,
             fn done, _test_data ->
               expect(ServerManagerMock, :connection_idle, fn state, ^test_pid ->
                 task = Task.async(fn -> :timer.sleep(1_000_000) end)

                 # Unlink the task so that killing it does not also kill the
                 # server manager.
                 Process.unlink(task.pid)

                 # Send the task's PID to the test process so that we can
                 # kill it.
                 send(test_pid, {:task, task.pid})

                 %ServerManagerState{
                   state
                   | actions: [
                       # Demonitor the task so that when we kill it, the server
                       # manager does not receive a killed message for it.
                       demonitor(task.ref)
                     ]
                 }
               end)

               expect(ServerManagerMock, :retry_connecting, fn state, true ->
                 done.(state)
               end)

               # Receive the task PID from the server manager.
               :ok = ServerManager.connection_idle(server.id, test_pid)
               assert_receive {:task, task_pid}, 500

               # Kill the task.
               Process.exit(task_pid, :kill)

               # Make sure the server manager is still working.
               ServerManager.notify_server_up(server.id)
             end
           ) == :ok
  end

  test "have a server manager check open ports", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    expect(Http.Mock, :get, 2, fn
      "http://1.2.3.4:42", opts ->
        assert Keyword.get(opts, :max_retries) == 1
        {:ok, %Response{status: 200, body: "OK"}}

      "http://1.2.3.4:24", opts ->
        assert Keyword.get(opts, :max_retries) == 1
        {:ok, %Response{status: 400, body: "Bad Request"}}
    end)

    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :connection_idle, fn state, ^test_pid ->
               %ServerManagerState{
                 state
                 | actions: [
                     {:check_open_ports,
                      fn task_state, task_factory ->
                        task = task_factory.({1, 2, 3, 4}, [42, 24])
                        Process.unlink(task.pid)
                        task_state
                      end}
                   ]
               }
             end)

             expect(ServerManagerMock, :handle_task_result, fn state, task_ref, :ok ->
               Process.demonitor(task_ref, [:flush])
               done.(state)
             end)

             :ok = ServerManager.connection_idle(server.id, test_pid)
           end) == :ok
  end

  test "have a server manager check open ports and report any problems", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    expect(Http.Mock, :get, 3, fn
      "http://1.2.3.4:3000", opts ->
        assert Keyword.get(opts, :max_retries) == 1
        {:error, %FakeHttpError{message: "Connection timeout"}}

      "http://1.2.3.4:4000", opts ->
        assert Keyword.get(opts, :max_retries) == 1
        {:ok, %Response{status: 200, body: "OK"}}

      "http://1.2.3.4:5000", opts ->
        assert Keyword.get(opts, :max_retries) == 1
        {:error, %FakeHttpError{message: "Connection refused"}}
    end)

    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :connection_idle, fn state, ^test_pid ->
               %ServerManagerState{
                 state
                 | actions: [
                     {:check_open_ports,
                      fn task_state, task_factory ->
                        task = task_factory.({1, 2, 3, 4}, [3000, 4000, 5000])
                        Process.unlink(task.pid)
                        task_state
                      end}
                   ]
               }
             end)

             expect(ServerManagerMock, :handle_task_result, fn state,
                                                               task_ref,
                                                               {:error,
                                                                [
                                                                  {3000,
                                                                   %FakeHttpError{
                                                                     message: "Connection timeout"
                                                                   }},
                                                                  {5000,
                                                                   %FakeHttpError{
                                                                     message: "Connection refused"
                                                                   }}
                                                                ]} ->
               Process.demonitor(task_ref, [:flush])
               done.(state)
             end)

             :ok = ServerManager.connection_idle(server.id, test_pid)
           end) == :ok
  end

  test "have a server manager gather ansible facts for its server", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    fake_facts = %{"cake" => "lie", "truth" => "out there"}

    expect(Ansible.Mock, :gather_facts, fn ^server, "alice" ->
      {:ok, fake_facts}
    end)

    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :connection_idle, fn state, ^test_pid ->
               %ServerManagerState{
                 state
                 | actions: [
                     {:gather_facts,
                      fn task_state, task_factory ->
                        task = task_factory.("alice")
                        Process.unlink(task.pid)
                        task_state
                      end}
                   ]
               }
             end)

             expect(ServerManagerMock, :handle_task_result, fn state,
                                                               task_ref,
                                                               {:ok, ^fake_facts} ->
               Process.demonitor(task_ref, [:flush])
               done.(state)
             end)

             :ok = ServerManager.connection_idle(server.id, test_pid)
           end) == :ok
  end

  for ansible_error <- [
        :unreachable,
        :invalid_json_output,
        :unknown,
        "arbitrary"
      ] do
    test "have a server manager report ansible fact gathering #{ansible_error} error for its server",
         %{
           initialize: initialize,
           server: server,
           test_pid: test_pid
         } do
      fake_error = unquote(ansible_error)

      expect(Ansible.Mock, :gather_facts, fn ^server, "alice" ->
        {:error, fake_error}
      end)

      assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
               expect(ServerManagerMock, :connection_idle, fn state, ^test_pid ->
                 %ServerManagerState{
                   state
                   | actions: [
                       {:gather_facts,
                        fn task_state, task_factory ->
                          task = task_factory.("alice")
                          Process.unlink(task.pid)
                          task_state
                        end}
                     ]
                 }
               end)

               expect(ServerManagerMock, :handle_task_result, fn state,
                                                                 task_ref,
                                                                 {:error, ^fake_error} ->
                 Process.demonitor(task_ref, [:flush])
                 done.(state)
               end)

               :ok = ServerManager.connection_idle(server.id, test_pid)
             end) == :ok
    end
  end

  test "have a server manager request that the ansible pipeline queue run a playbook for its server",
       %{
         initialize: initialize,
         server: server,
         test: test,
         test_pid: test_pid
       } do
    server_id = server.id
    queue_name = AnsiblePipelineQueue.name(test)
    playbook_run = ServersFactory.build(:ansible_playbook_run, server: server, state: :pending)
    playbook_run_id = playbook_run.id

    # Start a fake ansible pipeline queue process that will forward all calls to
    # the test process.
    start_link_supervised!(%{
      id: AnsiblePipelineQueue,
      start: {GenServerProxy, :start_link, [self(), queue_name]}
    })

    init_actions = [{:run_playbook, playbook_run}]

    assert test_server_manager!(
             initialize,
             test_pid,
             fn done, %{starting_version: starting_version} ->
               expect(ServerManagerMock, :connection_idle, fn state, ^test_pid ->
                 done.(%ServerManagerState{state | version: starting_version})
               end)

               assert_receive {:proxy, ^queue_name,
                               {:call, {:run_playbook, ^playbook_run_id, ^server_id}, from}},
                              500

               GenServer.reply(from, :ok)

               ServerManager.connection_idle(server.id, test_pid)
             end,
             actions: init_actions,
             wait_for_started_message: false
           ) == :ok
  end

  test "have a server manager notify the ansible pipeline queue that it is offline",
       %{
         initialize: initialize,
         server: server,
         test: test,
         test_pid: test_pid
       } do
    server_id = server.id
    queue_name = AnsiblePipelineQueue.name(test)

    # Start a fake ansible pipeline queue process that will forward all calls to
    # the test process.
    start_link_supervised!(%{
      id: AnsiblePipelineQueue,
      start: {GenServerProxy, :start_link, [self(), queue_name]}
    })

    init_actions = [:notify_server_offline]

    assert test_server_manager!(
             initialize,
             test_pid,
             fn done, _test_data ->
               expect(ServerManagerMock, :connection_idle, fn state, ^test_pid ->
                 done.(state)
               end)

               assert_receive {:proxy, ^queue_name, {:cast, {:server_offline, ^server_id}}}, 500

               ServerManager.connection_idle(server.id, test_pid)
             end,
             actions: init_actions
           ) == :ok
  end

  test "have a server manager run a command on its server",
       %{
         initialize: initialize,
         server: server,
         test_pid: test_pid
       } do
    server_conn_name = ServerConnection.name(server)

    # Start a fake server connection process that will forward all calls to the
    # test process.
    start_link_supervised!(%{
      id: ServerConnection,
      start: {GenServerProxy, :start_link, [self(), server_conn_name]}
    })

    fake_command = Faker.Lorem.sentence()
    fake_timeout = Faker.random_between(1, 1_000_000)
    fake_result = Faker.random_between(1, 1_000_000)

    init_actions = [
      {:run_command,
       fn task_state, task_factory ->
         task = task_factory.(fake_command, fake_timeout)
         Process.unlink(task.pid)
         task_state
       end}
    ]

    assert test_server_manager!(
             initialize,
             test_pid,
             fn done, _test_data ->
               expect(ServerManagerMock, :handle_task_result, fn state,
                                                                 task_ref,
                                                                 {:ok, ^fake_result} ->
                 Process.demonitor(task_ref, [:flush])
                 done.(state)
               end)

               assert_receive {:proxy, ^server_conn_name,
                               {:call, {:run_command, ^fake_command}, from}},
                              500

               GenServer.reply(from, {:ok, fake_result})

               :ok
             end,
             actions: init_actions
           ) == :ok
  end

  test "notify a server manager that its connection is idle", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :connection_idle, fn state, ^test_pid ->
               done.(state)
             end)

             ServerManager.connection_idle(server.id, test_pid)
           end) == :ok
  end

  test "notify a server manager that it should retry connecting to its server", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :retry_connecting, fn state, true ->
               done.(state)
             end)

             ServerManager.notify_server_up(server.id)
           end) == :ok
  end

  test "notify a server manager that an ansible playbook event is running", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    run = ServersFactory.build(:ansible_playbook_run, server: server, state: :running)
    run_id = run.id

    task_name = Faker.Lorem.sentence()
    event = ServersFactory.build(:ansible_playbook_event, run: run, task_name: task_name)

    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :ansible_playbook_event, fn state, ^run_id, ^task_name ->
               done.(state)
             end)

             ServerManager.ansible_playbook_event(run, event)
           end) == :ok
  end

  test "send a completed ansible playbook run to a server manager", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    run = ServersFactory.build(:ansible_playbook_run, server: server, state: :succeeded)
    run_id = run.id

    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :ansible_playbook_completed, fn state, ^run_id ->
               done.(state)
             end)

             ServerManager.ansible_playbook_completed(run)
           end) == :ok
  end

  test "ask a server manager whether its server is online", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    online = bool()

    assert test_server_manager!(
             initialize,
             test_pid,
             fn _done, _test_data ->
               expect(ServerManagerMock, :online?, fn _state ->
                 online
               end)

               ServerManager.online?(server)
             end,
             wait_for_done_action: false
           ) == online
  end

  test "request a server manager to retry connecting to its server", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :retry_connecting, fn state, true ->
               done.(state)
             end)

             ServerManager.retry_connecting(server)
           end) == :ok
  end

  test "request a server manager to retry running an ansible playbook", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    playbook = Faker.Lorem.word()
    result = Enum.random([:ok, {:error, :server_not_connected}, {:error, :server_busy}])

    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :retry_ansible_playbook, fn state, ^playbook ->
               {done.(state), result}
             end)

             ServerManager.retry_ansible_playbook(server, playbook)
           end) == result
  end

  test "request a server manager to retry checking open ports", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    result = Enum.random([:ok, {:error, :server_not_connected}, {:error, :server_busy}])

    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :retry_checking_open_ports, fn state ->
               {done.(state), result}
             end)

             ServerManager.retry_checking_open_ports(server)
           end) == result
  end

  test "update a server through its manager", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    updated_server = %Server{server | username: Faker.Internet.user_name()}
    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)
    data = ServersFactory.random_update_server_data()

    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :update_server, fn state, ^auth, ^data ->
               {done.(state), {:ok, updated_server}}
             end)

             ServerManager.update_server(server, auth, data)
           end) == {:ok, updated_server}
  end

  test "fail to update a server through its manager", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    new_server_username = Faker.Internet.user_name()
    updated_server = %Server{server | username: new_server_username}
    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)
    data = ServersFactory.random_update_server_data()

    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :update_server, fn state, ^auth, ^data ->
               {done.(state), {:ok, updated_server}}
             end)

             ServerManager.update_server(server, auth, data)
           end) == {:ok, updated_server}
  end

  test "delete a server through its manager", %{
    server: server,
    test: test,
    test_pid: test_pid
  } do
    state_factory = fn ->
      allow(Ansible.Mock, test_pid, self())
      allow(Http.Mock, test_pid, self())
      allow(ServerManagerMock, test_pid, self())
      ServerManagerMock
    end

    server_opts = [state: state_factory]
    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    expect(ServerManagerMock, :on_message, fn state, :started ->
      send(test_pid, :started)
      state
    end)

    expect(ServerManagerMock, :delete_server, fn state, ^auth ->
      {state, :ok}
    end)

    server_manager_pid =
      initialize_server_manager(server, server_opts, test, [send_message(:started)],
        link: false,
        restart: :transient
      )

    assert_receive :started, 500
    assert Process.alive?(server_manager_pid)

    assert ServerManager.delete_server(server, auth) == :ok
    refute Process.alive?(server_manager_pid)
  end

  test "fail to delete a server through its manager", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    assert test_server_manager!(initialize, test_pid, fn done, _test_data ->
             expect(ServerManagerMock, :delete_server, fn state, ^auth ->
               {done.(state), {:error, :server_busy}}
             end)

             ServerManager.delete_server(server, auth)
           end) == {:error, :server_busy}
  end

  test "send a message to a server manager that it should retry connecting to its server", %{
    initialize: initialize,
    test_pid: test_pid
  } do
    assert test_server_manager!(initialize, test_pid, fn done, %{manager_pid: manager_pid} ->
             expect(ServerManagerMock, :retry_connecting, fn state, false ->
               done.(state)
             end)

             send(manager_pid, :retry_connecting)
           end) == :retry_connecting
  end

  test "send the result of an asynchronous task to a server manager", %{
    initialize: initialize,
    test_pid: test_pid
  } do
    fake_task_ref = make_ref()
    fake_result = {:ok, Faker.Lorem.sentence()}

    assert test_server_manager!(initialize, test_pid, fn done, %{manager_pid: manager_pid} ->
             expect(ServerManagerMock, :handle_task_result, fn state,
                                                               ^fake_task_ref,
                                                               ^fake_result ->
               done.(state)
             end)

             send(manager_pid, {fake_task_ref, fake_result})
           end) == {fake_task_ref, fake_result}
  end

  test "send an updated class to a server manager", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    updated_class = CourseFactory.build(:class, id: server.group_id)

    assert test_server_manager!(initialize, test_pid, fn done, %{manager_pid: manager_pid} ->
             expect(ServerManagerMock, :group_updated, fn state, ^updated_class ->
               done.(state)
             end)

             send(manager_pid, {:class_updated, updated_class})
           end) == {:class_updated, updated_class}
  end

  test "send a message to a server manager indicating that its connection has crashed", %{
    initialize: initialize,
    test_pid: test_pid
  } do
    fake_error = {:error, Faker.Lorem.sentence()}
    fake_connection_ref = make_ref()

    assert test_server_manager!(initialize, test_pid, fn done, %{manager_pid: manager_pid} ->
             expect(ServerManagerMock, :connection_crashed, fn state, ^test_pid, ^fake_error ->
               done.(state)
             end)

             send(manager_pid, {:DOWN, fake_connection_ref, :process, test_pid, fake_error})
           end) == {:DOWN, fake_connection_ref, :process, test_pid, fake_error}
  end

  defp test_server_manager!(initialize_fn, test_pid, test_fn, opts! \\ []) do
    {actions, opts!} = Keyword.pop(opts!, :actions, [])
    {wait_for_done_action, opts!} = Keyword.pop(opts!, :wait_for_done_action, true)
    {wait_for_started_message, opts!} = Keyword.pop(opts!, :wait_for_started_message, true)
    [] = opts!

    # Generate random versions that we will use to make sure that the server
    # manager actually updates its state between actions.
    starting_version = Faker.random_between(1, 1_000_000)
    done_version = Faker.random_between(starting_version + 1, 2_000_000)

    # Have the server manager forward the :started message to the test process.
    # We use this message to know when the server manager has finished
    # initializing (including processing its initial actions).
    if wait_for_started_message do
      expect(ServerManagerMock, :on_message, fn state, :started ->
        send(test_pid, :started)
        # Add the starting version so that we can verify later that the server
        # manager has actually updated its state during initialization.
        %ServerManagerState{state | version: starting_version}
      end)
    end

    if wait_for_done_action do
      # Have the server manager forward the :done message to the test process.
      # We use this message to know when the server manager has finished
      # processing its actions. We also verify that the server manager's state
      # was previously updated by checking that its version matches the expected
      # done version.
      expect(ServerManagerMock, :on_message, fn %ServerManagerState{version: ^done_version} =
                                                  state,
                                                {:done, ^done_version} ->
        send(test_pid, :done)
        state
      end)
    end

    # Initialize the server manager and wait for it to finish initializing.
    base_actions = if wait_for_started_message, do: [send_message(:started)], else: []
    server_manager_pid = initialize_fn.(base_actions ++ actions)

    if wait_for_started_message do
      assert_receive :started, 500
    end

    done_action = send_message({:done, done_version})

    # Define a function that appends a done action to the server manager's
    # actions, and updates its version to the done version. This function also
    # verifies that the server manager's version matches the starting version,
    # hence it was correctly initialized.
    done_action_fn = fn %ServerManagerState{version: ^starting_version} = state ->
      %ServerManagerState{state | actions: [done_action | state.actions], version: done_version}
    end

    result =
      test_fn.(done_action_fn, %{
        manager_pid: server_manager_pid,
        starting_version: starting_version
      })

    if wait_for_done_action do
      # Ensure that the server manager has received has processed the done action.
      assert_receive :done, 500
    end

    result
  end

  defp initialize_server_manager(server, server_opts, pipeline, actions, opts! \\ []) do
    {link, opts!} = Keyword.pop(opts!, :link, true)
    {restart, opts!} = Keyword.pop(opts!, :restart, :permanent)
    [] = opts!

    id = server.id
    test_pid = self()

    expect(ServerManagerMock, :init, fn ^id, ^pipeline ->
      send(test_pid, :initialized)

      %ServerManagerState{
        server: server,
        pipeline: pipeline,
        username: "alice",
        actions: actions
      }
    end)

    server_child_spec = %{
      id: ServerManager,
      start: {ServerManager, :start_link, [id, pipeline, server_opts]},
      restart: restart
    }

    server_manager_pid =
      if link do
        start_link_supervised!(server_child_spec)
      else
        start_supervised!(server_child_spec)
      end

    assert_receive :initialized, 500
    refute_received _anything_else

    server_manager_pid
  end

  defp cancel_timer(ref), do: {:cancel_timer, ref}

  defp connect(host, port, username) do
    test_pid = self()

    {:connect,
     fn state, task_factory ->
       task = task_factory.(host, port, username, silently_accept_hosts: true)
       send(test_pid, {:connect_task, task})
       state
     end}
  end

  defp monitor(pid), do: {:monitor, pid}
  defp demonitor(pid), do: {:demonitor, pid}

  defp send_message(message, ms \\ 0),
    do:
      {:send_message,
       fn state, task_factory ->
         task_factory.(message, ms)
         state
       end}
end
