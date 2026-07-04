defmodule ArchiDep.Support.SSHServerContainer do
  @moduledoc """
  Starts a throwaway Ubuntu SSH server with Python installed for the external
  Ansible compatibility smoke test (see the "Testing external-tool
  compatibility" section in `docs/testing.md`).

  Ansible gathers facts and runs modules by executing Python on the managed node
  over SSH, so — unlike the pure SSH round-trip, which an in-process
  `:ssh.daemon` can serve (see `ArchiDep.Support.SSHDaemon`) — the Ansible
  round-trip needs a real host. This module builds the `test/docker/ssh-server`
  image (which authorizes the `test/priv/ssh` client fixture and matches the
  Ubuntu student-VM fleet) and runs it as a container, mapping its SSH port to
  an ephemeral host port. The returned address plugs straight into
  `ArchiDep.Servers.Ansible.Runner`, whose connection options use the same
  fixture key.

  The container is torn down with `on_exit/1`, so the caller must run inside an
  ExUnit test process.
  """

  alias Testcontainers.Container
  alias Testcontainers.LogWaitStrategy
  alias Testcontainers.PullPolicy

  @enforce_keys [:host, :port, :username]
  defstruct [:host, :port, :username]

  @type t :: %__MODULE__{
          host: :inet.ip_address(),
          port: :inet.port_number(),
          username: String.t()
        }

  @image "archidep-ssh-server:test"
  @context_dir Path.expand("../docker/ssh-server", __DIR__)
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
      |> Container.with_exposed_port(@ssh_port)
      |> Container.with_waiting_strategy(LogWaitStrategy.new(~r/Server listening on/, 30_000))

    {:ok, container} = Testcontainers.start_container(config)
    ExUnit.Callbacks.on_exit(fn -> Testcontainers.stop_container(container.container_id) end)

    %__MODULE__{
      host: resolve_host(Testcontainers.get_host(container)),
      port: Testcontainers.get_port(container, @ssh_port),
      username: @username
    }
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
