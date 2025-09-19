defmodule ArchiDepWeb.Admin.Classes.NewClassDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Admin.Classes.ClassFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Course
  alias ArchiDepWeb.Admin.Classes.ClassForm

  @id "new-class-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close, do: close_dialog(@id)

  @impl LiveComponent
  def mount(socket),
    do: socket |> assign(form: to_form(ClassForm.create_changeset(%{}), as: :class)) |> ok()

  @impl LiveComponent

  def handle_event("add_teacher_ssh_public_key", _params, socket) do
    form = socket.assigns.form

    socket
    |> assign(form: form |> ClassForm.add_teacher_ssh_public_key() |> to_form(as: :class))
    |> noreply()
  end

  def handle_event("closed", _params, socket),
    do:
      socket
      |> assign(form: to_form(ClassForm.create_changeset(%{}), as: :class))
      |> noreply()

  def handle_event("validate", %{"class" => params}, socket) do
    auth = socket.assigns.auth

    changeset = ClassForm.create_changeset(params)

    validate_dialog_form(
      :class,
      ClassForm.create_changeset(params),
      fn data -> auth |> Course.validate_class(ClassForm.to_class_data(data)) |> ok() end,
      socket
    )

    case Changeset.apply_action(changeset, :validate) do
      {:ok, form_data} ->
        class_changeset = Course.validate_class(auth, ClassForm.to_class_data(form_data))

        socket
        |> assign(
          form:
            to_form(%Changeset{changeset | errors: class_changeset.errors},
              as: :class,
              action: :validate
            )
        )
        |> noreply()

      {:error, %Changeset{} = result_changeset} ->
        socket
        |> assign(
          form:
            to_form(%Changeset{changeset | errors: changeset.errors ++ result_changeset.errors},
              as: :class
            )
        )
        |> noreply()
    end
  end

  def handle_event("create", %{"class" => params}, socket) do
    auth = socket.assigns.auth

    changeset = ClassForm.create_changeset(params)

    with {:ok, form_data} <- Changeset.apply_action(changeset, :validate),
         {:ok, created_class} <-
           Course.create_class(auth, ClassForm.to_class_data(form_data)) do
      socket
      |> send_notification(
        Message.new(:success, gettext("Created class {class}", class: created_class.name))
      )
      |> push_event("execute-action", %{to: "##{id()}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = result_changeset} ->
        socket
        |> assign(
          form:
            to_form(%Changeset{changeset | errors: changeset.errors ++ result_changeset},
              as: :class
            )
        )
        |> noreply()
    end
  end
end
