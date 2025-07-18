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
      fn data -> auth |> Course.validate_class(ClassForm.to_class_data(data)) |> ok() end,
      socket
    )
  end

  def handle_event("create", %{"class" => params}, socket) do
    with {:ok, form_data} <-
           Changeset.apply_action(ClassForm.create_changeset(params), :validate),
         {:ok, created_class} <-
           Course.create_class(socket.assigns.auth, ClassForm.to_class_data(form_data)) do
      socket
      |> send_notification(
        Message.new(:success, gettext("Created class {class}", class: created_class.name))
      )
      |> push_event("execute-action", %{to: "##{id()}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        socket |> assign(form: to_form(changeset, as: :class)) |> noreply()
    end
  end
end
