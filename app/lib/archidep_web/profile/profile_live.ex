defmodule ArchiDepWeb.Profile.ProfileLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Accounts
  alias ArchiDepWeb.Profile.CurrentSessionsLive

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth
    user_account = Accounts.user_account(auth)

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
    end

    socket
    |> assign(page_title: "Profile", user_account: user_account)
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
