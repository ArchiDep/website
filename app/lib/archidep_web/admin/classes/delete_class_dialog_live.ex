defmodule ArchiDepWeb.Admin.Classes.DeleteClassDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Students
  alias ArchiDep.Students.Schemas.Class

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
        students: Students.list_students(assigns.auth, assigns.class)
      )
      |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket), do: {:noreply, socket}

  def handle_event("delete", _params, socket) do
    auth = socket.assigns.auth
    class = socket.assigns.class

    with :ok <- Students.delete_class(auth, class.id) do
      {:noreply,
       socket
       |> put_flash(:info, "Class deleted")
       |> push_navigate(to: ~p"/admin/classes")}
    end
  end
end
