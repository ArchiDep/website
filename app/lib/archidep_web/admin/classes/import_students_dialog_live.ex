defmodule ArchiDepWeb.Admin.Classes.ImportStudentsDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers

  @id "import-students-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close(), do: close_dialog(@id)

  @impl LiveComponent
  def mount(socket) do
    socket
    |> assign(state: :waiting_for_upload, students: [], columns: [])
    |> ok()
  end

  @impl LiveComponent

  def handle_event("closed", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    socket
    |> consume_uploaded_students()
    |> case do
      nil ->
        assign(socket, :state, :waiting_for_upload)

      [] ->
        assign(socket, :state, :invalid_upload)

      students ->
        assign(socket,
          state: :uploaded,
          students: students,
          columns: students |> Enum.flat_map(&Map.keys/1) |> Enum.uniq()
        )
    end
    |> noreply()
  end

  defp consume_uploaded_students(socket),
    do:
      consume_uploaded_entries(socket, :students, fn %{path: path}, _entry ->
        path
        |> File.stream!()
        |> CSV.decode(
          field_transform: &String.trim/1,
          headers: true
        )
        |> Enum.filter(fn
          {:ok, _row} -> true
          _ -> false
        end)
        |> Enum.reduce([], fn
          {:ok, row}, acc -> [row | acc]
          _, acc -> acc
        end)
        |> Enum.reverse()
        |> Enum.to_list()
        |> ok()
      end)
      |> List.first()
end
