defmodule ArchiDepWeb.Servers.EditServerDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Servers.ServerFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDepWeb.Servers.ServerForm

  @base_id "edit-server-dialog"

  @spec id(Server.t()) :: String.t()
  def id(%Server{id: id}), do: "#{@base_id}-#{id}"

  @spec close(Server.t()) :: js
  def close(server), do: server |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        server: assigns.server,
        form: to_form(ServerForm.update_changeset(assigns.server, %{}), as: :server)
      )
      |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket),
    do:
      socket
      |> assign(
        form: to_form(ServerForm.update_changeset(socket.assigns.server, %{}), as: :server)
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
        ServerForm.to_server_data(&1)
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
         {:ok, _server} <-
           Servers.update_server(auth, server.id, ServerForm.to_server_data(form_data)) do
      {:noreply,
       socket
       |> put_flash(:info, "Server updated")
       |> push_navigate(to: ~p"/servers/#{server.id}")}
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :server))}
    end
  end
end
