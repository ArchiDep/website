defmodule ArchiDepWeb.Admin.Classes.NewStudentDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Components.FormComponents
  alias __MODULE__
  alias ArchiDep.Students
  alias ArchiDepWeb.Admin.Classes.CreateStudentForm

  @id "new-student-dialog"
  @html_id "##{@id}"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close(),
    do:
      %JS{}
      |> JS.push("closed", target: @html_id)
      |> JS.dispatch("close-dialog", detail: %{dialog: @id})

  @impl LiveComponent
  def mount(socket),
    do:
      socket
      |> assign(form: to_form(CreateStudentForm.changeset(%{}), as: :student))
      |> ok()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        class: assigns.class,
        classes: Students.list_classes(assigns.auth)
      )
      |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket) do
    socket
    |> assign(form: to_form(CreateStudentForm.changeset(%{}), as: :student))
    |> noreply()
  end

  def handle_event("validate", %{"student" => params}, socket) do
    with {:ok, form_data} <-
           Changeset.apply_action(CreateStudentForm.changeset(params), :validate) do
      changeset = Students.validate_student(socket.assigns.auth, Map.from_struct(form_data))
      {:noreply, assign(socket, form: to_form(changeset, as: :student, action: :validate))}
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :student))}
    end
  end

  def handle_event("create", %{"student" => params}, socket) do
    class = socket.assigns.class

    with {:ok, form_data} <-
           Changeset.apply_action(CreateStudentForm.changeset(params), :validate),
         {:ok, _student} <-
           Students.create_student(socket.assigns.auth, Map.from_struct(form_data)) do
      {:noreply,
       socket
       |> put_flash(:info, "Student created")
       |> push_navigate(to: ~p"/admin/classes/#{class.id}")}
    else
      {:error, %Changeset{} = changeset} ->
        IO.puts("@@@ #{inspect(changeset)}")
        {:noreply, assign(socket, form: to_form(changeset, as: :student))}
    end
  end
end
