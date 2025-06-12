defmodule ArchiDep.Servers.Ansible do
  require Logger
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.Server

  @type ansible_host_stats :: %{
          changed: non_neg_integer(),
          failures: non_neg_integer(),
          ignored: non_neg_integer(),
          ok: non_neg_integer(),
          rescued: non_neg_integer(),
          skipped: non_neg_integer(),
          unreachable: non_neg_integer()
        }

  @playbooks_dir Path.expand("../../../priv/ansible/playbooks", __DIR__)
  @playbooks @playbooks_dir
             |> File.ls!()
             |> Enum.filter(&String.ends_with?(&1, ".yml"))
             |> Enum.map(fn filename ->
               digest =
                 Path.join(@playbooks_dir, filename)
                 |> File.stream!(2048)
                 |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
                 |> :crypto.hash_final()
                 |> Base.encode64()

               name = String.replace_suffix(filename, ".yml", "")
               playbook = AnsiblePlaybook.new(Path.join(@playbooks_dir, filename), digest)

               {name, playbook}
             end)
             |> Enum.into(%{})

  def playbook!(name) do
    case Map.fetch(@playbooks, name) do
      {:ok, playbook} ->
        playbook

      :error ->
        raise ArgumentError,
              "Playbook #{name} not found. Available playbooks: #{inspect(Map.keys(@playbooks))}"
    end
  end

  @spec gather_facts(Server.t()) ::
          {:ok, %{String.t() => term()}}
          | {:error, :unreachable}
          | {:error, String.t()}
          | {:error, :invalid_json_output}
          | {:error, :unknown}
  def gather_facts(server) do
    ansible_host = :inet.ntoa(server.ip_address.address)
    ansible_port = server.ssh_port || 22
    ansible_user = server.username

    results =
      [
        "ansible",
        "archidep",
        "-i",
        "archidep,",
        "-e",
        "ansible_host=#{ansible_host}",
        "-e",
        "ansible_port=#{ansible_port}",
        "-e",
        "ansible_user=#{ansible_user}",
        "-m",
        "gather_facts"
      ]
      |> ExCmd.stream(
        env: [
          {"ANSIBLE_HOST_KEY_CHECKING", "false"},
          {"ANSIBLE_LOAD_CALLBACK_PLUGINS", "1"},
          {"ANSIBLE_STDOUT_CALLBACK", "ansible.posix.json"}
        ],
        exit_timeout: 30_000
      )
      |> Enum.into([])

    {exit_result, parts} = List.pop_at(results, -1)

    case [Enum.join(parts, ""), exit_result] do
      [facts, {:exit, {:status, 0}}] when is_binary(facts) ->
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

          {:ok, _} ->
            Logger.error("Failed to decode Ansible facts #{inspect(facts)}")
            {:error, :invalid_json_output}

          {:error, reason} ->
            Logger.error(
              "Failed to decode Ansible facts #{inspect(facts)} because: #{inspect(reason)}"
            )

            {:error, :invalid_json_output}
        end

      [facts, {:exit, reason}] when is_binary(facts) and facts != "" ->
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

      _anything_else ->
        {:error, :unknown}
    end
  end

  @spec run_playbook(AnsiblePlaybook.t(), Server.t()) ::
          :ok | {:error, term}
  def run_playbook(playbook, server)
      when is_struct(playbook, AnsiblePlaybook) and is_struct(server, Server) do
    ansible_host = :inet.ntoa(server.ip_address.address)
    ansible_port = server.ssh_port || 22
    ansible_user = server.username

    [
      "ansible-playbook",
      "-e",
      "ansible_port=#{ansible_port}",
      "-e",
      "ansible_user=#{ansible_user}",
      "-i",
      "#{ansible_host},",
      playbook.path
    ]
    |> ExCmd.stream(
      env: [
        {"ANSIBLE_HOST_KEY_CHECKING", "false"},
        {"ANSIBLE_STDOUT_CALLBACK", "ansible.posix.jsonl"}
      ],
      exit_timeout: 30_000
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
    |> Stream.each(&Logger.debug("Ansible playbook event: #{inspect(&1)}"))
    |> Stream.run()
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
end
