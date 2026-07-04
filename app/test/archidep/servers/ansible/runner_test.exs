defmodule ArchiDep.Servers.Ansible.RunnerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Cmd
  alias ArchiDep.Servers.Ansible.Runner
  alias ArchiDep.Servers.SSH

  setup :verify_on_exit!

  # `Runner` is a pure module: its only side effect is running an external
  # command through the `ArchiDep.Cmd` facade and parsing the resulting output
  # stream. We stub that facade (`Cmd.Mock`) and feed it canned stream elements
  # of the exact shape `ExCmd.stream/2` produces — binary chunks followed by a
  # final `{:exit, term()}` — so the parsing and exit handling can be driven
  # exhaustively without spawning a real `ansible`/`ansible-playbook` process.
  # Chunk boundaries are deliberately controlled (a single logical line is split
  # across several binaries) to exercise the partial-line accumulator, which a
  # real subprocess could not reproduce deterministically. This subprocess-
  # stubbing technique lives here, not in `docs/testing.md`: `Runner` is the
  # only module that runs an external command, so it is a one-off rather than
  # canon.

  @host {192, 168, 1, 10}
  @port 2222
  @user "deploy"

  defp gather_facts_payload(host_result),
    do: %{
      "plays" => [
        %{
          "tasks" => [
            %{
              "hosts" => %{"archidep" => host_result},
              "task" => %{"name" => "gather_facts"}
            }
          ]
        }
      ]
    }

  describe "gather_facts/3" do
    test "runs the ansible gather_facts command for the host" do
      expect(Cmd.Mock, :stream, fn command, opts ->
        send(self(), {:stream_called, command, opts})

        [
          JSON.encode!(
            gather_facts_payload(%{"action" => "gather_facts", "ansible_facts" => %{}})
          ),
          {:exit, {:status, 0}}
        ]
      end)

      assert Runner.gather_facts(@host, @port, @user) == {:ok, %{}}

      assert_received {:stream_called, command, opts}

      assert command == [
               "ansible",
               "archidep",
               "-i",
               "archidep,",
               "-e",
               "ansible_host=192.168.1.10",
               "-e",
               "ansible_port=2222",
               "-e",
               "ansible_ssh_private_key_file=\"#{SSH.ssh_private_key_file()}\"",
               "-e",
               "ansible_user=deploy",
               "-m",
               "gather_facts"
             ]

      assert opts == [
               env: [
                 {"ANSIBLE_HOST_KEY_CHECKING", "false"},
                 {"ANSIBLE_LOAD_CALLBACK_PLUGINS", "1"},
                 {"ANSIBLE_STDOUT_CALLBACK", "ansible.posix.json"}
               ],
               exit_timeout: 60_000
             ]
    end

    test "decodes the gathered facts, joining output split across chunks" do
      facts = %{"ansible_distribution" => "Ubuntu", "ansible_memtotal_mb" => 2048}

      json =
        JSON.encode!(
          gather_facts_payload(%{"action" => "gather_facts", "ansible_facts" => facts})
        )

      {first_chunk, second_chunk} = String.split_at(json, 10)

      expect(Cmd.Mock, :stream, fn _command, _opts ->
        [first_chunk, second_chunk, {:exit, {:status, 0}}]
      end)

      assert Runner.gather_facts(@host, @port, @user) == {:ok, facts}
    end

    test "returns the host message when ansible fails with a decodable error" do
      json =
        JSON.encode!(
          gather_facts_payload(%{
            "action" => "gather_facts",
            "msg" => "Failed to connect to the host via ssh"
          })
        )

      expect(Cmd.Mock, :stream, fn _command, _opts -> [json, {:exit, {:status, 4}}] end)

      assert Runner.gather_facts(@host, @port, @user) ==
               {:error, "Failed to connect to the host via ssh"}
    end

    test "returns :invalid_json_output when a successful run emits non-JSON output" do
      expect(Cmd.Mock, :stream, fn _command, _opts ->
        ["not json at all", {:exit, {:status, 0}}]
      end)

      log =
        capture_log(fn ->
          assert Runner.gather_facts(@host, @port, @user) == {:error, :invalid_json_output}
        end)

      assert log =~ ~s(Failed to decode Ansible facts "not json at all" because:)
    end

    test "returns :invalid_json_output when a successful run emits an unexpected shape" do
      json = JSON.encode!(%{"plays" => []})

      expect(Cmd.Mock, :stream, fn _command, _opts -> [json, {:exit, {:status, 0}}] end)

      log =
        capture_log(fn ->
          assert Runner.gather_facts(@host, @port, @user) == {:error, :invalid_json_output}
        end)

      assert log =~ "Failed to decode Ansible facts #{inspect(json)}"
    end

    test "returns :unknown when a failed run emits no output" do
      expect(Cmd.Mock, :stream, fn _command, _opts -> [{:exit, {:status, 2}}] end)

      assert Runner.gather_facts(@host, @port, @user) == {:error, :unknown}
    end

    test "returns :unknown when a failed run emits undecodable output" do
      expect(Cmd.Mock, :stream, fn _command, _opts -> ["boom", {:exit, {:status, 2}}] end)

      log =
        capture_log(fn ->
          assert Runner.gather_facts(@host, @port, @user) == {:error, :unknown}
        end)

      assert log =~ ~s(Ansible exited with {:status, 2} and output: "boom")
    end
  end

  describe "run_playbook/5" do
    test "runs the ansible-playbook command for the host with its variables" do
      expect(Cmd.Mock, :stream, fn command, opts ->
        send(self(), {:stream_called, command, opts})
        [{:exit, {:status, 0}}]
      end)

      assert run_playbook(%{"app" => "demo"}) == [{:exit, {:status, 0}}]

      assert_received {:stream_called, command, opts}

      assert command == [
               "ansible-playbook",
               "-i",
               "archidep,",
               "-e",
               "ansible_host=192.168.1.10",
               "-e",
               "ansible_port=2222",
               "-e",
               "ansible_ssh_private_key_file=\"#{SSH.ssh_private_key_file()}\"",
               "-e",
               "ansible_user=deploy",
               "-e",
               "app=\"demo\"",
               "/path/to/playbook.yml"
             ]

      assert opts == [
               env: [
                 {"ANSIBLE_HOST_KEY_CHECKING", "false"},
                 {"ANSIBLE_STDOUT_CALLBACK", "ansible.posix.jsonl"}
               ],
               exit_timeout: 60_000
             ]
    end

    test "decodes one playbook event per output line and passes the exit through" do
      first = %{"event" => "v2_playbook_on_start"}
      second = %{"event" => "v2_playbook_on_stats"}

      expect(Cmd.Mock, :stream, fn _command, _opts ->
        [JSON.encode!(first) <> "\n", JSON.encode!(second) <> "\n", {:exit, {:status, 0}}]
      end)

      assert run_playbook() == [{:event, first}, {:event, second}, {:exit, {:status, 0}}]
    end

    test "accumulates a single event split across several chunks without a newline" do
      event = %{"event" => "v2_runner_on_ok", "host" => "archidep"}
      json = JSON.encode!(event)
      {head, tail} = String.split_at(json, 6)

      expect(Cmd.Mock, :stream, fn _command, _opts ->
        [head, tail, "\n", {:exit, {:status, 0}}]
      end)

      assert run_playbook() == [{:event, event}, {:exit, {:status, 0}}]
    end

    test "flushes a trailing line that has no newline before the exit" do
      event = %{"event" => "v2_playbook_on_stats"}

      expect(Cmd.Mock, :stream, fn _command, _opts ->
        [JSON.encode!(event), {:exit, {:status, 0}}]
      end)

      assert run_playbook() == [{:event, event}, {:exit, {:status, 0}}]
    end

    test "drops an undecodable line and keeps the surrounding events" do
      event = %{"event" => "v2_playbook_on_play_start"}

      expect(Cmd.Mock, :stream, fn _command, _opts ->
        ["garbage line\n", JSON.encode!(event) <> "\n", {:exit, {:status, 0}}]
      end)

      log =
        capture_log(fn ->
          assert run_playbook() == [{:event, event}, {:exit, {:status, 0}}]
        end)

      assert log =~ ~s(Failed to decode Ansible playbook event "garbage line" because:)
    end

    test "passes a non-zero exit status through" do
      event = %{"event" => "v2_runner_on_failed"}

      expect(Cmd.Mock, :stream, fn _command, _opts ->
        [JSON.encode!(event) <> "\n", {:exit, {:status, 2}}]
      end)

      assert run_playbook() == [{:event, event}, {:exit, {:status, 2}}]
    end

    test "passes an epipe exit through" do
      expect(Cmd.Mock, :stream, fn _command, _opts -> [{:exit, :epipe}] end)

      assert run_playbook() == [{:exit, :epipe}]
    end
  end

  defp run_playbook(vars \\ %{}),
    do:
      "/path/to/playbook.yml"
      |> Runner.run_playbook(@host, @port, @user, vars)
      |> Enum.to_list()
end
