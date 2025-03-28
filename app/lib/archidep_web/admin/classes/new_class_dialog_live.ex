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
      {:ok, assign(socket, form: to_form(changeset, as: :class, action: :validate))}
    else
      {:error, changeset} ->
        {:ok, assign(socket, form: to_form(changeset, as: :class))}
    end
  end

  @impl LiveComponent

  def handle_event("opened", _params, socket) do
    socket
    |> assign(open: true)
    |> push_event("app:focus", %{id: @name_field_id})
    |> noreply()
  end

  def handle_event("validate", %{"class" => params}, socket) do
    with {:ok, form_data} <- Changeset.apply_action(CreateClassForm.changeset(params), :validate),
         changeset <-
           Students.validate_class(socket.assigns.auth, Map.from_struct(form_data)) do
      {:noreply, assign(socket, form: to_form(changeset, as: :class, action: :validate))}
    else
      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :class))}
    end
  end

  def handle_event("create", %{"class" => params}, socket) do
    case Students.create_class(socket.assigns.auth, params) do
      {:ok, _class} ->
        {:noreply,
         socket
         |> put_flash(:info, "Class created")
         |> push_navigate(to: ~p"/admin/classes")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :class))}
    end
  end
end
