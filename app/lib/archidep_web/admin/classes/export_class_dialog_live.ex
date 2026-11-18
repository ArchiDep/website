defmodule ArchiDepWeb.Admin.Classes.ExportClassDialogLive do
  @moduledoc """
  The export dialog of the admin class page. It shows the students matching the
  page's filters in one of the formats of `ArchiDepWeb.Admin.Classes.Export`,
  with secrets redacted, and offers to copy the full text or to download it.

  The students and their servers are read when the dialog opens, and are not
  updated while it stays open, so that the text does not change under the
  teacher's eyes. Reopening the dialog reads them again.
  """

  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Clock
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Servers
  alias ArchiDepWeb.Admin.Classes.Export
  alias ArchiDepWeb.Admin.Classes.Export.Emails
  alias ArchiDepWeb.Admin.Classes.StudentFilters

  @id "export-class-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec open() :: js
  def open, do: open_dialog(@id)

  @spec close() :: js
  def close, do: close_dialog(@id)

  @doc """
  Returns the path the given format is downloaded from, with the student
  filters as query parameters.
  """
  @spec download_path(ClassView.t(), module(), StudentFilters.t()) :: String.t()
  def download_path(class, format, filters) do
    case StudentFilters.to_params(filters) do
      params when map_size(params) == 0 -> ~p"/admin/classes/#{class.id}/export/#{format.id()}"
      params -> ~p"/admin/classes/#{class.id}/export/#{format.id()}?#{params}"
    end
  end

  @impl LiveComponent
  def mount(socket),
    do:
      socket
      |> assign(format: Emails, students: [], filters: StudentFilters.none())
      |> clear_export()
      |> ok()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        class: assigns.class,
        source_students: assigns.students,
        source_filters: assigns.filters
      )
      |> ok()

  @impl LiveComponent
  def handle_event("opened", _params, socket),
    do:
      socket
      |> assign(
        students:
          StudentFilters.filter(socket.assigns.source_filters, socket.assigns.source_students),
        filters: socket.assigns.source_filters,
        servers: nil,
        generated_at: Clock.now()
      )
      |> load_export()
      |> noreply()

  def handle_event("closed", _params, socket), do: socket |> clear_export() |> noreply()

  def handle_event("format", %{"format" => format_id}, socket) do
    case Export.fetch_format(format_id) do
      {:ok, format} -> socket |> assign(:format, format) |> load_export() |> noreply()
      {:error, :format_not_found} -> noreply(socket)
    end
  end

  defp clear_export(socket),
    do:
      assign(socket,
        servers: nil,
        generated_at: nil,
        export: nil,
        text: nil,
        display_text: nil,
        excluded: []
      )

  # The servers are read the first time a format that needs them is shown, and
  # kept for the other formats until the dialog is closed.
  defp load_export(%Socket{assigns: %{generated_at: nil}} = socket), do: socket

  defp load_export(%Socket{assigns: %{format: format, servers: nil}} = socket) do
    if format.needs_servers?() do
      case Servers.list_active_servers_in_group(socket.assigns.auth, socket.assigns.class.id) do
        {:ok, servers} -> socket |> assign(:servers, servers) |> render_export()
        {:error, :server_group_not_found} -> socket |> assign(:servers, []) |> render_export()
      end
    else
      render_export(socket)
    end
  end

  defp load_export(socket), do: render_export(socket)

  defp render_export(%Socket{assigns: assigns} = socket) do
    export =
      Export.new(assigns.class, assigns.students, assigns.servers || [], assigns.generated_at)

    assign(socket,
      export: export,
      text: Export.render(export, assigns.format, false),
      display_text: Export.render(export, assigns.format, true),
      excluded: Export.excluded_students(export, assigns.format)
    )
  end
end
