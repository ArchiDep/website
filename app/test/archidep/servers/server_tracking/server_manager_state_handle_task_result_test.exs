defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateHandleTaskResultTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{
      handle_task_result:
        protect({ServerManagerState, :handle_task_result, 3}, ServerManagerBehaviour)
    }
  end

  test "receive load average from the server", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_get_load_average_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{get_load_average: fake_get_load_average_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_get_load_average_ref,
        {:ok, "0.65 0.43 0.21 1/436 761182\n", "", 0}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_get_load_average_ref},
                 {:send_message, send_message_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :measure_load_average, 20_000 ->
             fake_timer_ref
           end) == %ServerManagerState{result | load_average_timer: fake_timer_ref}
  end

  test "receive malformed load average from the server", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_get_load_average_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{get_load_average: fake_get_load_average_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_get_load_average_ref,
        {:ok, "oops", "", 0}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_get_load_average_ref},
                 {:send_message, send_message_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :measure_load_average, 20_000 ->
             fake_timer_ref
           end) == %ServerManagerState{result | load_average_timer: fake_timer_ref}
  end

  test "receive failed load average from the server", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_get_load_average_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{get_load_average: fake_get_load_average_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_get_load_average_ref,
        {:ok, "", "Oops\n", Faker.random_between(1, 255)}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_get_load_average_ref},
                 {:send_message, send_message_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :measure_load_average, 20_000 ->
             fake_timer_ref
           end) == %ServerManagerState{result | load_average_timer: fake_timer_ref}
  end

  test "receive load average error from the server", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_get_load_average_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{get_load_average: fake_get_load_average_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_get_load_average_ref,
        {:error, Faker.Lorem.sentence()}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_get_load_average_ref},
                 {:send_message, send_message_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :measure_load_average, 20_000 ->
             fake_timer_ref
           end) == %ServerManagerState{result | load_average_timer: fake_timer_ref}
  end

  test "receive load average from the server while another task is in progress", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_check_access_ref = make_ref()
    fake_get_load_average_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{check_access: fake_check_access_ref, get_load_average: fake_get_load_average_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_get_load_average_ref,
        {:ok, "0.65 0.43 0.21 1/436 761182\n", "", 0}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_get_load_average_ref},
                 {:send_message, send_message_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{check_access: fake_check_access_ref}
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :measure_load_average, 20_000 ->
             fake_timer_ref
           end) == %ServerManagerState{result | load_average_timer: fake_timer_ref}
  end
end
