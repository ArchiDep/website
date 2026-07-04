defmodule ArchiDep.Servers.Ansible.SetupPlaybookSmokeTest do
  # Runs the real `priv/ansible/playbooks/setup.yml` — the playbook students'
  # servers are provisioned with — against a throwaway Ubuntu host that boots
  # systemd, and certifies the machinery it installs actually works on a real
  # host: the playbook does its work and converges, the boot-time notify unit
  # sends the server-up callback the app expects, and the downloaded port tester
  # opens the ports the server manager probes. This is the drift canary for the
  # playbook itself — an Ubuntu, ansible-core, collection or released-binary
  # change that breaks provisioning fails here, where every mocked pipeline test
  # would miss it. Unlike `RunnerCompatibilityTest`, which pins the callback
  # output format with a trivial playbook, this drives the production playbook
  # end to end. See the "Testing external-tool compatibility" section in
  # `docs/testing.md`.
  use ExUnit.Case, async: true

  import Hammox
  alias ArchiDep.Servers.Ansible.Runner
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Support.UbuntuServerContainer

  @moduletag :external

  @playbook Path.join(File.cwd!(), "priv/ansible/playbooks/setup.yml")

  @api_base_url "https://archidep.example.test"
  @server_id "b7e8c2d1-4a3a-4c9b-9f2e-1e6b7a5d2c3f"
  @server_token "smoke-test-token"
  # A well-known valid key (the `test/priv/ssh` fixture public key). The
  # playbook forces the authorized-key comment to `ArchiDep`, so the installed
  # key carries that comment rather than the input's `archidep` — a rewrite the
  # state projection below certifies.
  @authorized_key_input "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE1Q2L2jlt2R71iHClMbx1uIIkKbBGMwGo5c1gFJVArH archidep"

  # The ports `ArchiDep.Servers.ServerTracking.ServerManagerState` probes via
  # `sudo test-ports`; the port-tester test opens exactly these.
  @port_tester_ports [80, 443, 3000, 3001]

  # A fake `curl` that records its argument vector, so the notify test can
  # assert exactly what the unit's script asks curl to send without needing a
  # reachable endpoint (the image ships no real curl anyway). curl's own output
  # is never consumed, so there is no tool-output contract to exercise — only
  # the request the script constructs, which the recorded argv captures.
  @curl_shim """
  #!/usr/bin/env bash
  for arg in "$@"; do printf '%s\\n' "$arg"; done > /tmp/curl-invocation
  """

  # One `bash` invocation projecting the whole post-setup state of the host into
  # `key=value` lines, so the test asserts every artifact the playbook is
  # responsible for at once. Each field suppresses stderr and tolerates a
  # missing target, so an artifact the playbook failed to create surfaces as an
  # empty value that fails the whole-map equality below rather than as noise.
  @state_script """
  echo "app_user_groups=$(id -nG archidep 2>/dev/null)"
  echo "app_user_shell=$(getent passwd archidep 2>/dev/null | cut -d: -f7)"
  echo "app_user_home=$(getent passwd archidep 2>/dev/null | cut -d: -f6)"
  echo "authorized_keys_perms=$(stat -c '%a %U:%G' /home/archidep/.ssh/authorized_keys 2>/dev/null)"
  echo "authorized_keys_content=$(cat /home/archidep/.ssh/authorized_keys 2>/dev/null)"
  echo "config_dir_perms=$(stat -c '%a %U:%G' /etc/archidep 2>/dev/null)"
  echo "server_id_perms=$(stat -c '%a %U:%G' /etc/archidep/server-id 2>/dev/null)"
  echo "server_id_content=$(cat /etc/archidep/server-id 2>/dev/null)"
  echo "token_perms=$(stat -c '%a %U:%G' /etc/archidep/token 2>/dev/null)"
  echo "token_content=$(cat /etc/archidep/token 2>/dev/null)"
  echo "notify_script_perms=$(stat -c '%a %U:%G' /usr/local/sbin/archidep-notify-server-up 2>/dev/null)"
  echo "notify_callback_url=$(grep -oE 'https?://[^\"]+' /usr/local/sbin/archidep-notify-server-up 2>/dev/null | head -1)"
  echo "notify_unit_perms=$(stat -c '%a %U:%G' /etc/systemd/system/archidep-notify-server-up.service 2>/dev/null)"
  echo "notify_enabled=$(systemctl is-enabled archidep-notify-server-up.service 2>/dev/null || true)"
  echo "notify_active=$(systemctl is-active archidep-notify-server-up.service 2>/dev/null || true)"
  echo "port_tester_perms=$(stat -c '%a %U:%G' /usr/local/bin/port-tester 2>/dev/null)"
  echo "test_ports_perms=$(stat -c '%a %U:%G' /usr/local/sbin/test-ports 2>/dev/null)"
  echo "sudoers_perms=$(stat -c '%a' /etc/sudoers.d/archidep 2>/dev/null)"
  echo "app_user_passwordless_sudo=$(runuser -u archidep -- sudo -n whoami 2>/dev/null || echo denied)"
  """

  setup :verify_on_exit!

  setup_all do
    target = UbuntuServerContainer.start!()
    # Provision once here so the per-test assertions below are independent of
    # ExUnit's randomized order (they only need the host already set up). The
    # `Cmd` façade mock must be stubbed in this process too, since `run_setup/1`
    # runs the real ansible-playbook here (see the per-test `setup` for the
    # `stub/3`-not-`stub_with/2` rationale).
    stub(ArchiDep.Cmd.Mock, :stream, &ExCmd.stream/2)
    setup_run = run_setup(target)

    # Fail the whole module with one actionable error (the SSH reason when the
    # host was unreachable) rather than letting every slice test cascade off an
    # unprovisioned host.
    if List.last(setup_run) != {:exit, {:status, 0}} do
      raise provisioning_error(target, setup_run)
    end

    %{target: target, setup_run: setup_run}
  end

  setup do
    # Point the compile-time `Cmd` façade mock at real ExCmd so `Runner`'s
    # `Cmd.stream/2` runs the real ansible-playbook subprocess. `stub/3` maps
    # the one callback to `ExCmd.stream/2` directly, since `ExCmd` does not
    # declare the `Cmd` behaviour and so cannot be passed to `stub_with/2`.
    # Driving `Runner` from the test process keeps the stub in scope (no spawned
    # task).
    stub(ArchiDep.Cmd.Mock, :stream, &ExCmd.stream/2)
    :ok
  end

  test "the real setup.yml provisions a production-like host", %{
    target: target,
    setup_run: setup_run
  } do
    # A fresh host, so every task but fact-gathering reports changed (that the
    # run succeeded at all is enforced by `setup_all`).
    assert stats(setup_run) == %{
             "changed" => 12,
             "failures" => 0,
             "ignored" => 0,
             "ok" => 13,
             "rescued" => 0,
             "skipped" => 0,
             "unreachable" => 0
           }

    # The whole state the playbook is responsible for, asserted at once.
    assert host_state(target) == %{
             "app_user_groups" => "archidep sudo",
             "app_user_shell" => "/bin/bash",
             "app_user_home" => "/home/archidep",
             "authorized_keys_perms" => "600 archidep:archidep",
             "authorized_keys_content" =>
               "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE1Q2L2jlt2R71iHClMbx1uIIkKbBGMwGo5c1gFJVArH ArchiDep",
             "config_dir_perms" => "750 archidep:archidep",
             "server_id_perms" => "640 archidep:archidep",
             "server_id_content" => @server_id,
             "token_perms" => "640 archidep:archidep",
             "token_content" => @server_token,
             "notify_script_perms" => "755 root:root",
             "notify_callback_url" => "#{@api_base_url}/callbacks/servers/${server_id}/up",
             "notify_unit_perms" => "644 root:root",
             "notify_enabled" => "enabled",
             "notify_active" => "inactive",
             "port_tester_perms" => "755 root:root",
             "test_ports_perms" => "755 root:root",
             "sudoers_perms" => "440",
             "app_user_passwordless_sudo" => "root"
           }
  end

  test "the real setup.yml is idempotent", %{target: target} do
    # A second run against the already-provisioned host changes nothing, proving
    # every task is genuinely convergent.
    rerun = run_setup(target)

    assert List.last(rerun) == {:exit, {:status, 0}}

    assert stats(rerun) == %{
             "changed" => 0,
             "failures" => 0,
             "ignored" => 0,
             "ok" => 13,
             "rescued" => 0,
             "skipped" => 0,
             "unreachable" => 0
           }
  end

  test "the boot-time notify unit sends the server-up callback the app expects", %{target: target} do
    install_curl_shim(target)

    # Drive the real oneshot unit through systemd (as it would fire at boot),
    # not the script directly, so the unit's ExecStart wiring is exercised too.
    UbuntuServerContainer.exec!(target, [
      "systemctl",
      "start",
      "archidep-notify-server-up.service"
    ])

    assert captured_curl(target) == [
             "-vv",
             "-X",
             "POST",
             "-H",
             "Content-Type: application/json",
             "-H",
             "Authorization: Bearer #{@server_token}",
             "#{@api_base_url}/callbacks/servers/#{@server_id}/up"
           ]
  end

  test "the port tester opens the ports the server manager probes", %{target: target} do
    # The exact command `ServerManagerState` runs over SSH, as the app user.
    UbuntuServerContainer.exec!(
      target,
      ["runuser", "-u", "archidep", "--", "sudo", "/usr/local/sbin/test-ports"] ++
        Enum.map(@port_tester_ports, &Integer.to_string/1)
    )

    assert listening_ports(target, @port_tester_ports) ==
             Map.new(@port_tester_ports, fn port -> {port, "listening"} end)
  end

  # A freshly booted host can briefly refuse the first SSH connection before
  # sshd is fully serving it; Ansible reports that as unreachable (exit status
  # 4) having run no task. Retry a few times so a transient not-yet-ready
  # connection does not fail the provision — a genuinely unreachable host still
  # fails once the attempts are exhausted. Retrying is safe precisely because an
  # unreachable run changed nothing.
  defp run_setup(target, attempts \\ 3) do
    result =
      @playbook
      |> Runner.run_playbook(target.host, target.port, target.username, setup_vars())
      |> Enum.to_list()

    if attempts > 1 and List.last(result) == {:exit, {:status, 4}} do
      Process.sleep(2_000)
      run_setup(target, attempts - 1)
    else
      result
    end
  end

  defp setup_vars do
    %{
      "api_base_url" => @api_base_url,
      "app_user_name" => "archidep",
      "app_user_authorized_key" => @authorized_key_input,
      "server_id" => @server_id,
      "server_token" => @server_token
    }
  end

  defp stats(elements) do
    Enum.find_value(elements, fn
      {:event, %{"stats" => %{"archidep" => host_stats}}} -> host_stats
      _other -> nil
    end)
  end

  defp provisioning_error(target, elements) do
    reason =
      Enum.find_value(elements, fn
        {:event,
         %{"_event" => "v2_runner_on_unreachable", "hosts" => %{"archidep" => %{"msg" => msg}}}} ->
          msg

        _other ->
          nil
      end)

    base =
      "setup.yml did not complete: #{inspect(List.last(elements))}" <>
        if reason, do: " (#{reason})", else: ""

    base <> verbose_connection_diagnosis(target)
  end

  # Temporary CI diagnostic: the provision fails to reach the host on CI but not
  # locally, and the parsed events carry no reason. Re-run the exact command with
  # `-vvvv` and stderr captured so the failure log shows the actual SSH
  # negotiation and error. Remove once the cause is understood.
  defp verbose_connection_diagnosis(target) do
    args =
      [
        "-i",
        "archidep,",
        "-e",
        "ansible_host=#{:inet.ntoa(target.host)}",
        "-e",
        "ansible_port=#{target.port}",
        "-e",
        "ansible_ssh_private_key_file=#{SSH.ssh_private_key_file()}",
        "-e",
        "ansible_user=#{target.username}",
        "-vvvv"
      ] ++
        Enum.flat_map(setup_vars(), fn {key, value} -> ["-e", "#{key}=#{value}"] end) ++
        [@playbook]

    {output, code} =
      try do
        System.cmd("ansible-playbook", args,
          env: [{"ANSIBLE_HOST_KEY_CHECKING", "false"}],
          stderr_to_stdout: true
        )
      rescue
        error -> {"diagnostic command could not run: #{Exception.message(error)}", -1}
      end

    tail = output |> String.split("\n") |> Enum.take(-120) |> Enum.join("\n")

    "\n\n--- diagnostic: ansible-playbook -vvvv " <>
      "target=#{:inet.ntoa(target.host)}:#{target.port} user=#{target.username} " <>
      "(exit #{code}) ---\n#{tail}"
  end

  defp host_state(target) do
    target
    |> UbuntuServerContainer.exec!(["bash", "-c", @state_script])
    |> String.split("\n", trim: true)
    |> Map.new(fn line ->
      [key, value] = String.split(line, "=", parts: 2)
      {key, value}
    end)
  end

  defp install_curl_shim(target) do
    encoded = Base.encode64(@curl_shim)

    UbuntuServerContainer.exec!(target, [
      "bash",
      "-c",
      "echo #{encoded} | base64 -d > /usr/bin/curl && chmod +x /usr/bin/curl"
    ])
  end

  defp captured_curl(target) do
    target
    |> UbuntuServerContainer.exec!(["cat", "/tmp/curl-invocation"])
    |> String.split("\n", trim: true)
  end

  # `test-ports` launches the port testers in the background, so poll until
  # every requested port is listening (or give up), then return the whole map
  # for a single equality assertion.
  defp listening_ports(target, ports, attempts \\ 20) do
    status = port_status(target, ports)

    if attempts <= 1 or Enum.all?(status, fn {_port, state} -> state == "listening" end) do
      status
    else
      Process.sleep(250)
      listening_ports(target, ports, attempts - 1)
    end
  end

  defp port_status(target, ports) do
    checks =
      Enum.map_join(ports, "\n", fn port ->
        hex = port |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(4, "0")

        ~s(if grep -qiE " [0-9A-F]{8}:#{hex} [0-9A-F]{8}:0000 0A" /proc/net/tcp /proc/net/tcp6 2>/dev/null; then echo "#{port}=listening"; else echo "#{port}=down"; fi)
      end)

    target
    |> UbuntuServerContainer.exec!(["bash", "-c", checks])
    |> String.split("\n", trim: true)
    |> Map.new(fn line ->
      [port, state] = String.split(line, "=", parts: 2)
      {String.to_integer(port), state}
    end)
  end
end
