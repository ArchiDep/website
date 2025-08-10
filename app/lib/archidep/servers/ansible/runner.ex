defmodule ArchiDep.Servers.Ansible.Runner do
  @moduledoc """
  Ansible runner module that provides functions to gather facts and run
  playbooks on remote servers using the Ansible command line interface.
  """

  import ArchiDep.Helpers.NetHelpers, only: [is_ip_address: 1, is_network_port: 1]
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.Types
  require Logger

  @type ansible_host :: Types.ansible_host()
  @type ansible_port :: Types.ansible_port()
  @type ansible_user :: Types.ansible_user()
  @type ansible_variables :: Types.ansible_variables()

  @type ansible_playbook_event_data :: %{String.t() => term()}
  @type ansible_playbook_run_element :: {:event, ansible_playbook_event_data()} | {:exit, term()}

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
        "ansible_host=#{:inet.ntoa(host)}",
        "-e",
        "ansible_port=#{port}",
        "-e",
        "ansible_ssh_private_key_file=\"#{shell_escape(SSH.ssh_private_key_file())}\"",
        "-e",
        "ansible_user=#{user}",
        # Gather facts
        "-m",
        "gather_facts"
      ]
      |> ExCmd.stream(
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
    ([
       "ansible-playbook",
       "-i",
       "archidep,",
       "-e",
       "ansible_host=#{:inet.ntoa(host)}",
       "-e",
       "ansible_port=#{port}",
       "-e",
       "ansible_ssh_private_key_file=\"#{shell_escape(SSH.ssh_private_key_file())}\"",
       "-e",
       "ansible_user=#{user}"
     ] ++
       Enum.flat_map(vars, fn {key, value} ->
         ["-e", "#{key}=\"#{shell_escape(value)}\""]
       end) ++
       [playbook_path])
    |> ExCmd.stream(
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
              {to_ansible_playbook_events([acc <> first_part]), ""}

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

  defp shell_escape(value) when is_binary(value), do: String.replace(value, "\"", "\\\"")
end
