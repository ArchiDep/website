defmodule ArchiDepWeb.Admin.Classes.EditClassDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Admin.Classes.ClassFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDepWeb.Admin.Classes.ClassForm

  @base_id "edit-class-dialog"

  @spec id(Class.t()) :: String.t()
  def id(%Class{id: id}), do: "#{@base_id}-#{id}"

  @spec close(Class.t()) :: js
  def close(class), do: class |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        class: assigns.class,
        form: to_form(ClassForm.update_changeset(assigns.class, %{}), as: :class)
      )
      |> ok()

  @impl LiveComponent

  def handle_event("add_teacher_ssh_public_key", _params, socket) do
    form = socket.assigns.form

    socket
    |> assign(form: to_form(ClassForm.add_teacher_ssh_public_key(form), as: :class))
    |> noreply()
  end

  def handle_event("closed", _params, socket),
    do:
      socket
      |> assign(form: to_form(ClassForm.update_changeset(socket.assigns.class, %{}), as: :class))
      |> noreply()

  def handle_event("validate", %{"class" => params}, socket) do
    auth = socket.assigns.auth
    class = socket.assigns.class

    changeset = ClassForm.update_changeset(class, params)

    with {:ok, form_data} <- Changeset.apply_action(changeset, :validate),
         {:ok, result_changeset} <-
           Course.validate_existing_class(auth, class.id, ClassForm.to_class_data(form_data)) do
      socket
      |> assign(
        form:
          to_form(%Changeset{changeset | errors: result_changeset.errors},
            as: :class,
            action: :validate
          )
      )
      |> noreply()
    else
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

  def handle_event("update", %{"class" => params}, socket) do
    auth = socket.assigns.auth
    class = socket.assigns.class

    changeset = ClassForm.update_changeset(class, params)

    with {:ok, form_data} <- Changeset.apply_action(changeset, :validate),
         {:ok, updated_class} <-
           Course.update_class(auth, class.id, ClassForm.to_class_data(form_data)) do
      socket
      |> send_notification(
        Message.new(:success, gettext("Updated class {class}", class: updated_class.name))
      )
      |> push_event("execute-action", %{to: "##{id(class)}", action: "close"})
      |> noreply()
    else
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
end
