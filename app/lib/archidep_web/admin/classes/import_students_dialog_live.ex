defmodule ArchiDepWeb.Admin.Classes.ImportStudentsDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Students

  @id "import-students-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close(), do: close_dialog(@id)

  @impl LiveComponent
  def mount(socket) do
    socket
    |> assign(
      state: :waiting_for_upload,
      students: [],
      columns: [],
      name_column: nil,
      email_column: nil
    )
    |> allow_upload(:students, accept: ~w(.csv), max_entries: 1)
    |> ok()
  end

  @impl LiveComponent
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(existing_students: Students.list_students(assigns.auth, assigns.class))
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

      %{columns: columns, students: students} ->
        email_column_candidate =
          columns
          |> Enum.map(fn col ->
            {col,
             Enum.count(students, fn student ->
               student |> Map.get(col, "") |> String.contains?("@")
             end)}
          end)
          |> Enum.sort_by(fn {_col, count} -> -count end)
          |> Enum.map(&elem(&1, 0))
          |> Enum.at(0)

        name_column_candidate =
          Enum.at(columns, if(email_column_candidate == List.first(columns), do: 1, else: 0))

        assign(socket,
          state: :uploaded,
          students: students,
          columns: columns,
          email_column: email_column_candidate,
          name_column: name_column_candidate
        )
    end
    |> noreply()
  end

  defp consume_uploaded_students(socket),
    do:
      consume_uploaded_entries(socket, :students, fn %{path: path}, _entry ->
        headers =
          path
          |> File.stream!()
          |> CSV.decode(
            field_transform: &String.trim/1,
            headers: false
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
          |> Enum.take(1)
          |> Enum.flat_map(&Function.identity/1)
          |> Enum.filter(fn col -> col != "" end)

        students =
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

        {:ok, %{columns: headers, students: students}}
      end)
      |> List.first()
end
