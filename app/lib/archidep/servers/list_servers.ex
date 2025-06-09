defmodule ArchiDep.Servers.ListServers do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.Schemas.Server

  @spec list_my_servers(Authentication.t()) :: list(Server.t())
  def list_my_servers(auth) do
    authorize!(auth, Policy, :servers, :list_my_servers, nil)

    user = Authentication.fetch_user_account(auth)
    user_account_id = user.id

    Repo.all(
      from s in Server,
        join: ua in UserAccount,
        on: s.user_account_id == ua.id,
        where: s.user_account_id == ^user_account_id,
        order_by: [s.name, s.ip_address],
        preload: [user_account: ua]
    )
  end
end
