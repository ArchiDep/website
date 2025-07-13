defmodule ArchiDepWeb.Dashboard.DashboardLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Course

  @impl true
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    {:ok, student} =
      if has_role?(auth, :student) do
        Course.fetch_authenticated_student(auth)
      else
        {:ok, nil}
      end

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
    end

    socket
    |> assign(student: student)
    |> ok()
  end
end
