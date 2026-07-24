defmodule ArchiDepWeb.Admin.Classes.EditClassDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Admin.Classes.ClassFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.ClassView
  alias ArchiDepWeb.Admin.Classes.ClassForm

  @base_id "edit-class-dialog"

  @spec id(ClassView.t()) :: String.t()
  def id(%ClassView{id: id}), do: "#{@base_id}-#{id}"

  @spec close(ClassView.t()) :: js
  def close(class), do: class |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket) do
    class = assigns.class

    socket
    |> assign(assigns)
    |> assign(form: to_form(ClassForm.update_changeset(class, %{}), as: :class))
    |> ok()
  end

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
          to_form(
            %Changeset{changeset | errors: result_changeset.errors},
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
      # The dialog closes immediately below; the class read-model (with its new
      # values) flows back in through the parent's PubSub refresh, so the form
      # is reset from the current view rather than the write-side aggregate.
      socket
      |> send_notification(
        Message.new(:success, gettext("Updated class {class}", class: updated_class.name))
      )
      |> push_event("execute-action", %{to: "##{id(class)}", action: "close"})
      |> assign(form: to_form(ClassForm.update_changeset(class, %{}), as: :class))
      |> noreply()
    else
      {:error, %Changeset{} = result_changeset} ->
        socket
        |> assign(
          form:
            to_form(%Changeset{changeset | errors: changeset.errors ++ result_changeset.errors},
              as: :class,
              action: :update
            )
        )
        |> noreply()
    end
  end
end
