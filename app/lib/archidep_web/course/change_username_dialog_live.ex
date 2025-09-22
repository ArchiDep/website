defmodule ArchiDepWeb.Course.ChangeUsernameDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Components.FormComponents
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.Material
  alias ArchiDepWeb.Course.ChangeUsernameForm

  @id "change-username-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close, do: close_dialog(@id)

  @impl LiveComponent
  def update(assigns, socket) do
    student = assigns.student

    form =
      ChangeUsernameForm.changeset(student)

    socket
    |> assign(assigns)
    |> assign(form: to_form(form, as: :student_config))
    |> ok()
  end

  @impl LiveComponent
  def handle_event("closed", _params, socket), do: noreply(socket)

  @impl LiveComponent
  def handle_event("validate", %{"student_config" => params}, socket) when is_map(params) do
    auth = socket.assigns.auth
    student = socket.assigns.student
    form_changeset = ChangeUsernameForm.changeset(student, params)

    with {:ok, form_data} <- Changeset.apply_action(form_changeset, :validate),
         data = ChangeUsernameForm.to_data(form_data),
         {:ok, validated} <-
           Course.validate_student_config(auth, student.id, data) do
      socket
      |> assign(form: to_form(validated, as: :student_config, action: :validate))
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :student_config))}
    end
  end

  @impl LiveComponent
  def handle_event("configure", %{"student_config" => params}, socket) when is_map(params) do
    auth = socket.assigns.auth
    student = socket.assigns.student
    form_changeset = ChangeUsernameForm.changeset(student, params)

    with {:ok, form_data} <-
           Changeset.apply_action(form_changeset, :validate),
         data = ChangeUsernameForm.to_data(form_data),
         {:ok, configured_student} <-
           Course.configure_student(auth, student.id, data) do
      socket
      |> assign(
        form: to_form(ChangeUsernameForm.changeset(configured_student), as: :student_config)
      )
      |> send_notification(
        Message.new(
          :success,
          gettext("Username changed to {name}", name: configured_student.username)
        )
      )
      |> push_event("execute-action", %{to: "##{@id}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        socket |> assign(form: to_form(changeset, as: :student_config)) |> noreply()
    end
  end
end
