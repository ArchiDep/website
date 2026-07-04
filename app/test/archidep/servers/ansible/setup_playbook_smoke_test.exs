defmodule ArchiDep.Servers.Ansible.SetupPlaybookSmokeTest do
  # Runs the real `priv/ansible/playbooks/setup.yml` — the playbook students'
  # servers are provisioned with — against a throwaway Ubuntu host that boots
  # systemd, and asserts it does its work and converges. This is the drift
  # canary for the playbook itself: an Ubuntu, ansible-core or collection change
  # that breaks provisioning (a renamed module option, a systemd behaviour
  # change, a broken download) fails here, where every mocked pipeline test
  # would miss it. Unlike `RunnerCompatibilityTest`, which pins the callback
  # output format with a trivial playbook, this drives the production playbook
  # end to end. See the "Testing external-tool compatibility" section in
  # `docs/testing.md`.
  use ExUnit.Case, async: true

  import Hammox
  alias ArchiDep.Servers.Ansible.Runner
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
  """

  setup :verify_on_exit!

  setup_all do
    %{target: UbuntuServerContainer.start!()}
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

  test "the real setup.yml provisions a production-like host and is idempotent",
       %{target: target} do
    # First run: a fresh host, so every task but fact-gathering reports changed.
    first_run = run_setup(target)

    assert List.last(first_run) == {:exit, {:status, 0}}

    assert stats(first_run) == %{
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
             "sudoers_perms" => "440"
           }

    # Second run: nothing changes, proving every task is genuinely convergent.
    second_run = run_setup(target)

    assert List.last(second_run) == {:exit, {:status, 0}}

    assert stats(second_run) == %{
             "changed" => 0,
             "failures" => 0,
             "ignored" => 0,
             "ok" => 13,
             "rescued" => 0,
             "skipped" => 0,
             "unreachable" => 0
           }
  end

  defp run_setup(target) do
    vars = %{
      "api_base_url" => @api_base_url,
      "app_user_name" => "archidep",
      "app_user_authorized_key" => @authorized_key_input,
      "server_id" => @server_id,
      "server_token" => @server_token
    }

    @playbook
    |> Runner.run_playbook(target.host, target.port, target.username, vars)
    |> Enum.to_list()
  end

  defp stats(elements) do
    Enum.find_value(elements, fn
      {:event, %{"stats" => %{"archidep" => host_stats}}} -> host_stats
      _other -> nil
    end)
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
end
