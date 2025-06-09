defmodule ArchiDep.Servers.Types do
  @type create_server_data :: %{
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t(),
          ssh_port: integer() | nil
        }
end
