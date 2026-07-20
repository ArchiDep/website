defmodule ArchiDepWeb.Profile.ProfileLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Accounts
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Course
  alias ArchiDepWeb.Course.ChangeUsernameDialogLive
  alias ArchiDepWeb.LiveRefresh
  alias ArchiDepWeb.Profile.CurrentSessionsLive

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    user_account = Accounts.user_account(auth)

    {:ok, student} =
      if user_account.root do
        {:ok, nil}
      else
        Course.fetch_authenticated_student(auth)
      end

    socket
    |> assign(page_title: gettext("Profile"), user_account: user_account, student: student)
    |> track_student(auth, student)
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # On connected mount, subscribe to the student's read-model and keep the
  # `:student` assign current through the Course boundary. A root user has no
  # student and nothing to track.
  defp track_student(socket, auth, student) do
    if connected?(socket) do
      set_process_label(__MODULE__, auth)

      if student != nil do
        :ok = Course.subscribe_student(student)
        LiveRefresh.attach(socket, :student, &Course.refresh_student/2)
      else
        socket
      end
    else
      socket
    end
  end
end
