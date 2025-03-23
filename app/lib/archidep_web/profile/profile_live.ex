defmodule ArchiDepWeb.Profile.ProfileLive do
  use ArchiDepWeb, :live_view

  alias ArchiDep.Accounts
  alias ArchiDepWeb.Profile.CurrentSessionsLive

  def mount(_params, _session, socket) do
    user_account = Accounts.user_account(socket.assigns.auth)
    {:ok, assign(socket, :user_account, user_account)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
