defmodule ArchiDep.Servers.SSH.Client.Behaviour do
  @moduledoc """
  Behaviour of the module used to open SSH connections and run commands over
  them.
  """

  @type connection_ref :: :ssh.connection_ref()

  @callback connect(
              host :: :inet.ip_address(),
              port :: 1..65_535,
              opts :: keyword()
            ) :: {:ok, connection_ref()} | {:error, term()}

  @callback close(connection_ref()) :: :ok | {:error, term()}

  @callback run_command(connection_ref(), command :: String.t(), opts :: keyword()) ::
              {:ok, String.t(), String.t(), 0..255} | {:error, term()}
end
