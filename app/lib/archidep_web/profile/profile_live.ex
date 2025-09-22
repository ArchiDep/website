defmodule ArchiDepWeb.Profile.ProfileLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Accounts
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDepWeb.Course.ChangeUsernameDialogLive
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

    if connected?(socket) do
      set_process_label(__MODULE__, auth)

      if student != nil do
        :ok = Course.PubSub.subscribe_student(student.id)
      end
    end

    socket
    |> assign(page_title: gettext("Profile"), user_account: user_account, student: student)
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl LiveView
  def handle_info(
        {:student_updated, %Student{id: id} = updated_student},
        %Socket{
          assigns: %{
            student: %Student{id: id} = student
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: Student.refresh!(student, updated_student))
        |> noreply()
end
