defmodule ArchiDepWeb.Admin.Classes.NewClassDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Students
  alias ArchiDepWeb.Admin.Classes.CreateClassForm

  @id "new-class-dialog"
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
    do: socket |> assign(form: to_form(CreateClassForm.changeset(%{}), as: :class)) |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket),
    do:
      socket
      |> assign(form: to_form(CreateClassForm.changeset(%{}), as: :class))
      |> noreply()

  def handle_event("validate", %{"class" => params}, socket) do
    with {:ok, form_data} <- Changeset.apply_action(CreateClassForm.changeset(params), :validate) do
      changeset = Students.validate_class(socket.assigns.auth, Map.from_struct(form_data))
      {:noreply, assign(socket, form: to_form(changeset, as: :class, action: :validate))}
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :class))}
    end
  end

  def handle_event("create", %{"class" => params}, socket) do
    with {:ok, form_data} <- Changeset.apply_action(CreateClassForm.changeset(params), :validate),
         {:ok, _class} <- Students.create_class(socket.assigns.auth, Map.from_struct(form_data)) do
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
