defmodule ArchiDepWeb.Servers.NewServerDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  import ArchiDepWeb.Servers.ServerFormComponent
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDepWeb.Servers.ServerForm

  @id "new-server-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close, do: close_dialog(@id)

  @impl LiveComponent
  def mount(socket),
    do: ok(socket)

  @impl LiveComponent
  def update(assigns, socket) do
    auth = assigns.auth

    owner = ServerOwner.fetch_authenticated(auth)

    socket
    |> assign(assigns)
    |> assign(
      form: init_form(owner),
      owner: owner
    )
    |> ok()
  end

  @impl LiveComponent

  def handle_event("closed", _params, %Socket{assigns: %{owner: owner}} = socket),
    do:
      socket
      |> assign(form: init_form(owner))
      |> noreply()

  def handle_event("validate", %{"server" => params}, socket) do
    auth = socket.assigns.auth

    group_id =
      case socket.assigns.owner do
        %ServerOwner{group_member: %ServerGroupMember{group_id: gid}} -> gid
        _anything_else -> nil
      end

    validate_dialog_form(
      :server,
      ServerForm.create_changeset(params),
      fn data ->
        Servers.validate_server(auth, data.group_id || group_id, ServerForm.to_create_data(data))
      end,
      socket
    )
  end

  def handle_event("create", %{"server" => params}, socket) do
    auth = socket.assigns.auth

    group_id =
      case socket.assigns.owner do
        %ServerOwner{group_member: %ServerGroupMember{group_id: gid}} -> gid
        _anything_else -> nil
      end

    with {:ok, form_data} <-
           Changeset.apply_action(ServerForm.create_changeset(params), :validate),
         {:ok, created_server} <-
           Servers.create_server(
             auth,
             form_data.group_id || group_id,
             ServerForm.to_create_data(form_data)
           ) do
      socket
      |> send_notification(
        Message.new(
          :success,
          gettext("Registered server {server}", server: Server.name_or_default(created_server))
        )
      )
      |> push_event("execute-action", %{to: "##{id()}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        socket
        |> send_notification(Message.new(:error, gettext("The form is invalid.")))
        |> assign(form: to_form(changeset, as: :server))
        |> noreply()
    end
  end

  defp init_form(owner) do
    default_username =
      case owner.group_member do
        %ServerGroupMember{username: username} -> username
        _anything_else -> nil
      end

    to_form(ServerForm.create_changeset(%{username: default_username}), as: :server)
  end
end
