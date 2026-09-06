defmodule ArchiDep.Servers.Ansible.Runner do
  @moduledoc """
  Ansible runner module that provides functions to gather facts and run
  playbooks on remote servers using the Ansible command line interface.
  """

  @behaviour ArchiDep.Servers.Ansible.RunnerClientBehaviour

  import ArchiDep.Helpers.NetHelpers, only: [is_ip_address: 1, is_network_port: 1]
  alias ArchiDep.Cmd
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.Types
  require Logger

  @type ansible_host :: Types.ansible_host()
  @type ansible_port :: Types.ansible_port()
  @type ansible_user :: Types.ansible_user()
  @type ansible_variables :: Types.ansible_variables()

  @type ansible_playbook_event_data :: %{String.t() => term()}
  @type ansible_playbook_run_element :: {:event, ansible_playbook_event_data()} | {:exit, term()}

  @impl ArchiDep.Servers.Ansible.RunnerClientBehaviour
  @spec gather_facts(ansible_host(), ansible_port(), ansible_user()) ::
          {:ok, %{String.t() => term()}}
          | {:error, :unreachable}
          | {:error, String.t()}
          | {:error, :invalid_json_output}
          | {:error, :unknown}
  def gather_facts(host, port, user)
      when is_ip_address(host) and is_network_port(port) and
             is_binary(user) do
    results =
      [
        "ansible",
        # Single ad-hoc target host
        "archidep",
        # Ad-hoc inventory with only the single host
        "-i",
        "archidep,",
        # Host connection parameters
        "-e",
        extra_variables(host, port, user),
        # Gather facts
        "-m",
        "gather_facts"
      ]
      |> Cmd.stream(
        env: [
          {"ANSIBLE_HOST_KEY_CHECKING", "false"},
          # Output in JSON format
          {"ANSIBLE_LOAD_CALLBACK_PLUGINS", "1"},
          {"ANSIBLE_STDOUT_CALLBACK", "ansible.posix.json"}
        ],
        exit_timeout: 60_000
      )
      |> Enum.into([])

    {exit_result, parts} = List.pop_at(results, -1)
    facts = Enum.join(parts, "")

    decode_facts(facts, exit_result)
  end

  defp decode_facts(facts, {:exit, {:status, 0}}) when is_binary(facts) do
    case JSON.decode(facts) do
      {:ok,
       %{
         "plays" => [
           %{
             "tasks" => [
               %{
                 "hosts" => %{
                   "archidep" => %{
                     "action" => "gather_facts",
                     "ansible_facts" => ansible_facts
                   }
                 },
                 "task" => %{"name" => "gather_facts"}
               }
             ]
           }
         ]
       }} ->
        {:ok, ansible_facts}

      {:ok, _anything_else} ->
        Logger.error("Failed to decode Ansible facts #{inspect(facts)}")
        {:error, :invalid_json_output}

      {:error, reason} ->
        Logger.error(
          "Failed to decode Ansible facts #{inspect(facts)} because: #{inspect(reason)}"
        )

        {:error, :invalid_json_output}
    end
  end

  defp decode_facts(facts, {:exit, reason}) when is_binary(facts) and facts != "" do
    case JSON.decode(facts) do
      {:ok,
       %{
         "plays" => [
           %{
             "tasks" => [
               %{
                 "hosts" => %{"archidep" => %{"action" => "gather_facts", "msg" => msg}},
                 "task" => %{"name" => "gather_facts"}
               }
             ]
           }
         ]
       }} ->
        {:error, msg}

      _anything_else ->
        Logger.warning("Ansible exited with #{inspect(reason)} and output: #{inspect(facts)}")
        {:error, :unknown}
    end
  end

  defp decode_facts(_facts, _exit_result) do
    {:error, :unknown}
  end

  @impl ArchiDep.Servers.Ansible.RunnerClientBehaviour
  @spec run_playbook(
          String.t(),
          ansible_host(),
          ansible_port(),
          ansible_user(),
          ansible_variables()
        ) ::
          Enumerable.t(ansible_playbook_run_element())
  def run_playbook(playbook_path, host, port, user, vars)
      when is_binary(playbook_path) and is_ip_address(host) and is_network_port(port) and
             is_binary(user) and is_map(vars) do
    [
      "ansible-playbook",
      "-i",
      "archidep,",
      # Host connection parameters and the playbook's variables
      "-e",
      extra_variables(host, port, user, vars),
      playbook_path
    ]
    |> Cmd.stream(
      env: [
        {"ANSIBLE_HOST_KEY_CHECKING", "false"},
        # Output each event as a JSON object on a separate line
        {"ANSIBLE_STDOUT_CALLBACK", "ansible.posix.jsonl"}
      ],
      exit_timeout: 60_000
    )
    |> Stream.transform(
      fn -> "" end,
      fn
        {:exit, reason}, acc ->
          {to_ansible_playbook_events([acc || ""]) ++ [{:exit, reason}], ""}

        line, acc when is_binary(line) ->
          case String.split(line, "\n") do
            [""] ->
              {[], acc}

            [first_part] ->
              {[], acc <> first_part}

            [first_part | other_parts] ->
              {last_part, middle_parts} = List.pop_at(other_parts, -1)
              events = [acc <> first_part] ++ middle_parts
              {to_ansible_playbook_events(events), last_part}
          end
      end,
      fn
        "" ->
          {:halt, nil}

        acc ->
          {to_ansible_playbook_events([acc]), nil}
      end,
      fn _acc -> nil end
    )
  end

  defp to_ansible_playbook_events(lines),
    do:
      lines
      |> Enum.filter(&(&1 != ""))
      |> Enum.flat_map(fn line ->
        case JSON.decode(line) do
          {:ok, event} ->
            [{:event, event}]

          {:error, reason} ->
            Logger.error(
              "Failed to decode Ansible playbook event #{inspect(line)} because: #{inspect(reason)}"
            )

            []
        end
      end)

  # The value of the single `--extra-vars` argument carrying the host connection
  # parameters and, for a playbook, its variables.
  #
  # It is one JSON document rather than repeated `key=value` arguments because
  # Ansible parses an `--extra-vars` value that starts with `{` as JSON, which
  # keeps every value one opaque value. The `key=value` form instead splits the
  # value on whitespace and reads each resulting word as a further `key=value`
  # pair, so any value that may contain a space could define arbitrary other
  # variables — the connection parameters below among them.
  #
  # The connection parameters are merged last so that a playbook variable of the
  # same name can never take over the connection.
  defp extra_variables(host, port, user, vars \\ %{}),
    do:
      JSON.encode!(
        Map.merge(vars, %{
          "ansible_host" => host |> :inet.ntoa() |> to_string(),
          "ansible_port" => port,
          "ansible_ssh_private_key_file" => SSH.ssh_private_key_file(),
          "ansible_user" => user
        })
      )
end
