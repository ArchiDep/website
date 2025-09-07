defmodule ArchiDepWeb.Admin.Ansible.AnsiblePlaybookRunLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Admin.Ansible.AnsibleComponents
  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias Phoenix.LiveView.JS
  require Logger

  @impl LiveView
  def mount(%{"id" => run_id}, _session, socket) do
    auth = socket.assigns.auth

    socket
    |> assign(
      page_title: "#{gettext("ArchiDep")} > #{gettext("Admin")} > #{gettext("Ansible")}",
      playbook_run: auth |> Servers.fetch_ansible_playbook_run(run_id) |> unpair_ok(),
      now: DateTime.utc_now()
    )
    |> assign_async(:events, fn ->
      case Servers.fetch_ansible_playbook_events_for_run(auth, run_id) do
        {:ok, events} -> {:ok, %{events: events}}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket), do: noreply(socket)
end
