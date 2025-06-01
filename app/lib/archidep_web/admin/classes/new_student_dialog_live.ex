defmodule ArchiDepWeb.Admin.Classes.NewStudentDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Components.FormComponents
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Students
  alias ArchiDepWeb.Admin.Classes.CreateStudentForm

  @id "new-student-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close(), do: close_dialog(@id)

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        class: assigns.class,
        classes: Students.list_classes(assigns.auth),
        form: to_form(CreateStudentForm.changeset(%{}), as: :student)
      )
      |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket) do
    socket
    |> assign(form: to_form(CreateStudentForm.changeset(%{}), as: :student))
    |> noreply()
  end

  def handle_event("validate", %{"student" => params}, socket) do
    auth = socket.assigns.auth

    validate_dialog_form(
      :student,
      CreateStudentForm.changeset(params),
      fn data ->
        auth |> Students.validate_student(CreateStudentForm.to_student_data(data)) |> ok()
      end,
      socket
    )
  end

  def handle_event("create", %{"student" => params}, socket) do
    class = socket.assigns.class

    with {:ok, form_data} <-
           Changeset.apply_action(CreateStudentForm.changeset(params), :validate),
         {:ok, _student} <-
           Students.create_student(
             socket.assigns.auth,
             CreateStudentForm.to_student_data(form_data)
           ) do
      {:noreply,
       socket
       |> put_flash(:info, "Student created")
       |> push_navigate(to: ~p"/admin/classes/#{class.id}")}
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :student))}
    end
  end
end
