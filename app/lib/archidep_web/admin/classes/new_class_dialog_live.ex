defmodule ArchiDepWeb.Admin.Classes.NewClassDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Admin.Classes.ClassFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Students
  alias ArchiDepWeb.Admin.Classes.ClassForm

  @id "new-class-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close(), do: close_dialog(@id)

  @impl LiveComponent
  def mount(socket),
    do: socket |> assign(form: to_form(ClassForm.create_changeset(%{}), as: :class)) |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket),
    do:
      socket
      |> assign(form: to_form(ClassForm.create_changeset(%{}), as: :class))
      |> noreply()

  def handle_event("validate", %{"class" => params}, socket) do
    auth = socket.assigns.auth

    validate_dialog_form(
      :class,
      ClassForm.create_changeset(params),
      fn data -> auth |> Students.validate_class(ClassForm.to_class_data(data)) |> ok() end,
      socket
    )
  end

  def handle_event("create", %{"class" => params}, socket) do
    with {:ok, form_data} <-
           Changeset.apply_action(ClassForm.create_changeset(params), :validate),
         {:ok, _class} <-
           Students.create_class(socket.assigns.auth, ClassForm.to_class_data(form_data)) do
      {:noreply,
       socket
       |> put_flash(:info, "Class created")
       |> push_navigate(to: ~p"/admin/classes")}
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :class))}
    end
  end
end
