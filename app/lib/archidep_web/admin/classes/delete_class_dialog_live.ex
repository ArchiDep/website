defmodule ArchiDepWeb.Admin.Classes.DeleteClassDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class

  @base_id "delete-class-dialog"

  @spec id(Class.t()) :: String.t()
  def id(class), do: "#{@base_id}-#{class.id}"

  @spec close(Class.t()) :: js
  def close(class), do: class |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        class: assigns.class,
        servers_count: assigns.servers_count,
        students: Course.list_students(assigns.auth, assigns.class)
      )
      |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket), do: {:noreply, socket}

  def handle_event("delete", _params, socket) do
    auth = socket.assigns.auth
    class = socket.assigns.class

    case Course.delete_class(auth, class.id) do
      :ok ->
        noreply(socket)

      {:error, :class_has_servers} ->
        socket
        |> push_event("execute-action", %{to: "##{id(class)}", action: "close"})
        |> send_notification(
          Message.new(
            :error,
            gettext(
              "Class {class} cannot be deleted because at least one server is linked to it.",
              class: class.name
            )
          )
        )
        |> noreply()
    end
  end
end
