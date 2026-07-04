defmodule ArchiDep.Support.UbuntuServerContainer do
  @moduledoc """
  Starts a throwaway Ubuntu server that boots systemd, for the external
  compatibility smoke tests (see the "Testing external-tool compatibility"
  section in `docs/testing.md`).

  Ansible gathers facts and runs modules by executing Python on the managed node
  over SSH, so — unlike the pure SSH round-trip, which an in-process
  `:ssh.daemon` can serve (see `ArchiDep.Support.SSHDaemon`) — the Ansible
  round-trip needs a real host. The setup playbook additionally drives
  `ansible.builtin.systemd` (daemon-reload, enabling a unit), which needs a live
  systemd/dbus. This module builds the `test/docker/ubuntu-server` image (Ubuntu
  noble booting `/sbin/init`, matching the student-VM fleet and authorizing the
  `test/priv/ssh` client fixture) and runs it as a privileged container, mapping
  its SSH port to an ephemeral host port. The returned address plugs straight
  into `ArchiDep.Servers.Ansible.Runner`, whose connection options use the same
  fixture key.

  The container runs privileged so systemd can manage its own cgroups; on the
  cgroup-v2 hosts we target (GitHub `ubuntu-24.04` runners, Docker Desktop,
  colima) that is sufficient — no host cgroup mount or `--cgroupns=host` is
  needed. Because systemd routes unit logs to the journal rather than the
  container's stdout, readiness is gated on `systemctl is-active ssh` succeeding
  inside the container (which certifies the exact capability the Ansible
  round-trip needs) rather than on a stdout log line.

  The container is torn down with `on_exit/1`, so the caller must run inside an
  ExUnit test process.
  """

  alias Testcontainers.CommandWaitStrategy
  alias Testcontainers.Container
  alias Testcontainers.PortWaitStrategy
  alias Testcontainers.PullPolicy

  @enforce_keys [:host, :port, :username, :container_id]
  defstruct [:host, :port, :username, :container_id]

  @type t :: %__MODULE__{
          host: :inet.ip_address(),
          port: :inet.port_number(),
          username: String.t(),
          container_id: String.t()
        }

  @image "archidep-ubuntu-server:test"
  @context_dir Path.expand("../docker/ubuntu-server", __DIR__)
  @ssh_port 22
  # The container's pre-existing user, authorized for the fixture key.
  @username "jde"

  @doc """
  Builds the image if necessary, starts the container, and returns its address.
  Registers an `on_exit/1` callback that stops the container.
  """
  @spec start!() :: t()
  def start! do
    ensure_service_started!()
    build_image!()

    config =
      @image
      |> Container.new()
      |> Container.with_pull_policy(PullPolicy.never_pull())
      |> Container.with_privileged(true)
      |> Container.with_exposed_port(@ssh_port)
      # `is-active ssh` (run via `docker exec`) only proves sshd is up *inside*
      # the container. Also wait until the *published* SSH port accepts TCP
      # connections from the host — the path Ansible/`Runner` actually take — so
      # a caller that connects immediately after `start!/0` (e.g. a `setup_all`
      # that provisions right away) does not race an SSH port that is not yet
      # serving. The `PortWaitStrategy` ip argument is overridden with the
      # resolved Docker host, so its value here is irrelevant.
      |> Container.with_waiting_strategies([
        CommandWaitStrategy.new(["systemctl", "is-active", "ssh"], 30_000),
        PortWaitStrategy.new("127.0.0.1", @ssh_port, 30_000)
      ])

    {:ok, container} = Testcontainers.start_container(config)
    ExUnit.Callbacks.on_exit(fn -> Testcontainers.stop_container(container.container_id) end)

    %__MODULE__{
      host: resolve_host(Testcontainers.get_host(container)),
      port: Testcontainers.get_port(container, @ssh_port),
      username: @username,
      container_id: container.container_id
    }
  end

  @doc """
  Runs a command inside the container and returns its standard output, raising
  if it exits non-zero. Testcontainers' own exec primitive does not capture
  per-exec output, so this shells out to `docker exec` like `build_image!/0`
  shells out to `docker build`. Intended for tests that assert the state a
  playbook left behind.
  """
  @spec exec!(t(), [String.t()]) :: String.t()
  def exec!(%__MODULE__{container_id: container_id}, command) when is_list(command) do
    case System.cmd("docker", ["exec", container_id | command], env: [], stderr_to_stdout: true) do
      {output, 0} -> output
      {output, status} -> raise "docker exec exited #{status}: #{output}"
    end
  end

  # The Testcontainers service (its Docker connection and resource reaper) is
  # started lazily here rather than in `test_helper.exs`, so the default suite
  # — which never reaches this module — needs neither Docker nor the service.
  # `start/1` (not `start_link/1`) keeps the service alive past the ephemeral
  # `setup_all` process that first reaches it, so container teardown can still
  # reach it in `on_exit/1`.
  defp ensure_service_started! do
    case Testcontainers.start() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  defp build_image! do
    {_output, 0} =
      System.cmd("docker", ["build", "-t", @image, @context_dir],
        env: [],
        stderr_to_stdout: true
      )

    :ok
  end

  # `Runner` connects to an IP tuple; map the Docker host to one.
  defp resolve_host("localhost"), do: {127, 0, 0, 1}

  defp resolve_host(host) do
    case :inet.parse_address(to_charlist(host)) do
      {:ok, address} -> address
      {:error, _reason} -> {127, 0, 0, 1}
    end
  end
end
