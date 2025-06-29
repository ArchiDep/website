defmodule ArchiDepWeb.Servers.NewServerDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  import ArchiDepWeb.Servers.ServerFormComponent
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDepWeb.Servers.ServerForm

  @id "new-server-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close(), do: close_dialog(@id)

  @impl true
  def mount(socket),
    do: ok(socket)

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(form: to_form(ServerForm.create_changeset(%{}), as: :server))
    |> ok()
  end

  @impl true

  def handle_event("closed", _params, socket),
    do:
      socket
      |> assign(form: to_form(ServerForm.create_changeset(%{}), as: :server))
      |> noreply()

  def handle_event("validate", %{"server" => params}, socket) do
    auth = socket.assigns.auth

    validate_dialog_form(
      :server,
      ServerForm.create_changeset(params),
      fn data ->
        auth |> Servers.validate_server(ServerForm.to_create_server_data(data)) |> ok()
      end,
      socket
    )
  end

  def handle_event("create", %{"server" => params}, socket) do
    with {:ok, form_data} <-
           Changeset.apply_action(ServerForm.create_changeset(params), :validate),
         {:ok, created_server} <-
           Servers.create_server(socket.assigns.auth, ServerForm.to_create_server_data(form_data)) do
      socket
      |> send_notification(
        Message.new(:success, "Created server #{Server.name_or_default(created_server)}")
      )
      |> push_event("execute-action", %{to: "##{id()}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :server))}
    end
  end
end
