defmodule ArchiDepWeb.Admin.Classes.ImportStudentsDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers

  @id "import-students-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close(), do: close_dialog(@id)

  @impl LiveComponent

  def handle_event("closed", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end
end
