defmodule ArchiDepWeb.Admin.Classes.NewClassDialogLive do
  use ArchiDepWeb, :live_component

  alias ArchiDep.Students
  alias ArchiDepWeb.Admin.Classes.CreateClassForm

  @id "new-class-dialog"
  @html_id "##{@id}"
  @name_field_id "new-class-name"

  @spec id() :: String.t()
  def id, do: @id

  @spec open(js) :: js
  def open(js \\ %JS{}),
    do:
      js
      |> JS.add_class("modal-open", to: @html_id, transition: "fade-in")
      |> JS.push("opened", target: @html_id)

  @impl LiveComponent
  def mount(socket) do
    with {:ok, form_data} <- Changeset.apply_action(CreateClassForm.changeset(%{}), :validate),
         changeset <-
           Students.validate_class(socket.assigns.auth, form_data) do
      {:ok, assign(socket, form: to_form(changeset, action: :validate))}
    else
      {:error, changeset} ->
        {:ok, assign(socket, form: to_form(changeset))}
    end
  end

  @impl LiveComponent

  def handle_event("opened", _params, socket) do
    socket
    |> assign(open: true)
    |> push_event("app:focus", %{id: @name_field_id})
    |> noreply()
  end

  def handle_event("validate", %{"create_class_form" => params}, socket) do
    form =
      socket.assigns.auth
      |> Students.validate_class(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("create", %{"create_class_form" => params}, socket) do
    case Students.create_class(socket.assigns.auth, params) do
      {:ok, _class} ->
        {:noreply,
         socket
         |> put_flash(:info, "Class created")
         |> redirect(to: ~p"/admin/classes")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
