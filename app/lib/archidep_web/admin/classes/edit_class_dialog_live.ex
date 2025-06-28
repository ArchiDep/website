defmodule ArchiDepWeb.Admin.Classes.EditClassDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Admin.Classes.ClassFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Students
  alias ArchiDep.Students.Schemas.Class
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

  def handle_event("closed", _params, socket),
    do:
      socket
      |> assign(form: to_form(ClassForm.update_changeset(socket.assigns.class, %{}), as: :class))
      |> noreply()

  def handle_event("validate", %{"class" => params}, socket) do
    auth = socket.assigns.auth
    class = socket.assigns.class

    validate_dialog_form(
      :class,
      ClassForm.update_changeset(class, params),
      &Students.validate_existing_class(
        auth,
        class.id,
        ClassForm.to_class_data(&1)
      ),
      socket
    )
  end

  def handle_event("update", %{"class" => params}, socket) do
    auth = socket.assigns.auth
    class = socket.assigns.class

    with {:ok, form_data} <-
           Changeset.apply_action(
             ClassForm.update_changeset(class, params),
             :validate
           ),
         {:ok, _class} <-
           Students.update_class(auth, class.id, ClassForm.to_class_data(form_data)) do
      socket
      |> put_flash(:info, "Class updated")
      |> push_event("execute-action", %{to: "##{id(class)}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        socket |> assign(form: to_form(changeset, as: :class)) |> noreply()
    end
  end
end
