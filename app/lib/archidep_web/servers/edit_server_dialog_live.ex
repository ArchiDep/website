defmodule ArchiDepWeb.Servers.EditServerDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Servers.ServerFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDepWeb.Servers.ServerForm

  @base_id "edit-server-dialog"
  @base_change_detection_fields ~w(name ip_address username ssh_port ssh_host_key_fingerprints active)a
  @root_change_detection_fields ~w(app_username expected_properties)a

  @spec id(Server.t()) :: String.t()
  def id(%Server{id: id}), do: "#{@base_id}-#{id}"

  @spec open(Server.t()) :: js
  def open(server), do: server |> id() |> open_dialog()

  @spec close(Server.t()) :: js
  def close(server), do: server |> id() |> close_dialog()

  @spec changed_server(Server.t() | false, Server.t()) :: Server.t() | nil
  def changed_server(false, _new_server), do: nil
  def changed_server(%Server{version: version}, %Server{version: version}), do: nil
  def changed_server(_server, new_server), do: new_server

  @impl LiveComponent
  def mount(socket),
    do:
      socket
      |> assign(
        open: false,
        form: to_form(ServerForm.blank_changeset(), as: :server)
      )
      |> ok()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        server: assigns.server,
        state: assigns.state
      )
      |> update_form()
      |> ok()

  defp update_form(%Socket{assigns: %{open: false, server: server}} = socket),
    do:
      assign(socket,
        open: server,
        form: to_form(ServerForm.update_changeset(server, %{}), as: :server)
      )

  defp update_form(
         %Socket{assigns: %{open: %Server{version: version}, server: %Server{version: version}}} =
           socket
       ),
       do: socket

  defp update_form(
         %Socket{assigns: %{auth: auth, open: previous_server, server: new_server}} =
           socket
       ) do
    change_detection_fields =
      if root?(auth) do
        @base_change_detection_fields ++ @root_change_detection_fields
      else
        @base_change_detection_fields
      end

    if Server.changed?(previous_server, new_server, change_detection_fields) do
      socket
    else
      assign(socket, open: new_server)
    end
  end

  @impl LiveComponent

  def handle_event("opened", _params, %Socket{assigns: %{server: server}} = socket),
    do:
      socket
      |> assign(open: server)
      |> noreply()

  def handle_event("closed", _params, %Socket{assigns: %{server: server}} = socket),
    do:
      socket
      |> assign(
        open: false,
        form: to_form(ServerForm.update_changeset(server, %{}), as: :server)
      )
      |> noreply()

  def handle_event("validate", %{"server" => params}, socket) do
    auth = socket.assigns.auth
    server = socket.assigns.server

    validate_dialog_form(
      :server,
      ServerForm.update_changeset(server, params),
      &Servers.validate_existing_server(
        auth,
        server.id,
        ServerForm.to_update_data(&1)
      ),
      socket
    )
  end

  def handle_event("update", %{"server" => params}, socket) do
    auth = socket.assigns.auth
    server = socket.assigns.server

    with {:ok, form_data} <-
           Changeset.apply_action(
             ServerForm.update_changeset(server, params),
             :validate
           ),
         {:ok, updated_server, _event} <-
           Servers.update_server(auth, server.id, ServerForm.to_update_data(form_data)) do
      socket
      |> assign(open: false)
      |> send_notification(
        Message.new(
          :success,
          gettext("Updated server {server}", server: Server.name_or_default(updated_server))
        )
      )
      |> push_event("execute-action", %{to: "##{id(server)}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        socket
        |> send_notification(Message.new(:error, gettext("The form is invalid.")))
        |> assign(form: to_form(changeset, as: :server))
        |> noreply()
    end
  end
end
