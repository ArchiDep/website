defmodule ArchiDepWeb.Admin.Ansible.AnsiblePlaybookRunLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Admin.Ansible.AnsibleComponents
  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Clock
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias Phoenix.LiveView.JS
  require Logger

  @impl LiveView
  def mount(%{"id" => run_id}, _session, socket) do
    auth = socket.assigns.auth

    case Servers.fetch_ansible_playbook_run(auth, run_id) do
      {:ok, playbook_run} ->
        socket
        |> assign(
          page_title: "#{gettext("Ansible")} · #{gettext("Admin")}",
          playbook_run: playbook_run,
          now: Clock.now()
        )
        |> assign_async(:events, fn -> load_events(auth, run_id) end)
        |> ok()

      {:error, :ansible_playbook_run_not_found} ->
        socket
        |> put_notification(Message.new(:error, gettext("Ansible playbook run not found")))
        |> push_navigate(to: ~p"/admin/ansible")
        |> ok()
    end
  end

  @impl LiveView
  def handle_params(_params, _url, socket), do: noreply(socket)

  defp load_events(auth, run_id) do
    case Servers.fetch_ansible_playbook_events_for_run(auth, run_id) do
      {:ok, events} -> {:ok, %{events: events}}
      {:error, reason} -> {:error, reason}
    end
  end
end
