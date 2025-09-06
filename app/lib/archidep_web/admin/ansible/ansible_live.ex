defmodule ArchiDepWeb.Admin.Ansible.AnsibleLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Admin.Ansible.AnsibleComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
    end

    socket
    |> assign(
      page_title: "#{gettext("ArchiDep")} > #{gettext("Admin")} > #{gettext("Ansible")}",
      now: DateTime.utc_now(),
      playbook_runs: Servers.fetch_ansible_playbook_runs(auth)
    )
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket), do: noreply(socket)
end
