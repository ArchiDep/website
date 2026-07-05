defmodule ArchiDep.ReleaseTest do
  use ArchiDep.Support.DataCase, async: true

  import ExUnit.CaptureIO
  import Hammox
  alias ArchiDep.Clock
  alias ArchiDep.Release
  alias ArchiDep.Servers.ServerTracking.ServerConnection
  alias ArchiDep.Support.GenServerProxy
  alias ArchiDep.Support.ServersTestHelpers

  @now ~U[2024-03-15 10:30:00.000000Z]

  setup do
    # `ssh_student/3` reads the current time from the injectable clock (for the
    # active-student/active-server windows), so pin it to `@now`.
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  describe "ssh_student/3" do
    test "runs a command on the active student's server through its SSH connection" do
      %{owner: owner, student: student, class: class} =
        ServersTestHelpers.register_group_member(@now,
          class: [start_date: nil, end_date: nil],
          student: [name: "Alice Cooper"]
        )

      server = ServersTestHelpers.insert_server(owner.id, class.id, active: true)
      conn_name = proxy_server_connection(server)

      # `ssh_student/3` blocks on the `run_command` GenServer call, so it must run
      # in a separate process while this one acts as the proxied connection.
      task =
        Task.async(fn ->
          with_io(fn -> Release.ssh_student(student.name, ["ls", "-la", "/tmp"]) end)
        end)

      assert_receive {:proxy, ^conn_name, {:call, {:run_command, command, timeout}, from}}, 1_000
      assert command == "ls -la /tmp"
      assert timeout == 30_000

      GenServer.reply(from, {:ok, "file listing", "", 0})

      assert {result, _output} = Task.await(task)
      assert result == {:ok, %{exit_code: 0, stdout: "12 byte(s)", stderr: "0 byte(s)"}}
    end

    test "passes through an error from the SSH connection" do
      %{owner: owner, student: student, class: class} =
        ServersTestHelpers.register_group_member(@now,
          class: [start_date: nil, end_date: nil],
          student: [name: "Alice Cooper"]
        )

      server = ServersTestHelpers.insert_server(owner.id, class.id, active: true)
      conn_name = proxy_server_connection(server)

      task = Task.async(fn -> Release.ssh_student(student.name, ["ls"]) end)

      assert_receive {:proxy, ^conn_name, {:call, {:run_command, "ls", _timeout}, from}}, 1_000
      GenServer.reply(from, {:error, :not_connected})

      assert Task.await(task) == {:error, :not_connected}
    end

    test "returns an error when no active student matches the name" do
      assert Release.ssh_student("nobody", ["ls"]) == {:error, :student_not_found}
    end

    test "returns an error when the student has no active server" do
      %{student: student} =
        ServersTestHelpers.register_group_member(@now,
          class: [start_date: nil, end_date: nil],
          student: [name: "Alice Cooper"]
        )

      assert Release.ssh_student(student.name, ["ls"]) == {:error, :server_not_found}
    end
  end

  defp proxy_server_connection(server) do
    name = ServerConnection.name(server)

    start_supervised!(%{
      id: :server_connection_proxy,
      start: {GenServerProxy, :start_link, [self(), name]}
    })

    name
  end
end
