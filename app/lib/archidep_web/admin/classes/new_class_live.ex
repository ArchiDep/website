defmodule ArchiDepWeb.Admin.Classes.NewClassLive do
  use ArchiDepWeb, :live_view

  alias ArchiDep.Students
  alias ArchiDepWeb.Admin.Classes.CreateClassForm

  @impl LiveView
  def mount(_params, _session, socket) do
    with {:ok, form_data} <- Changeset.apply_action(CreateClassForm.changeset(%{}), :validate),
         changeset <-
           Students.validate_class(socket.assigns.auth, form_data) do
      {:ok, assign(socket, form: to_form(changeset, action: :validate))}
    else
      {:error, changeset} ->
        {:ok, assign(socket, form: to_form(changeset))}
    end
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl LiveView

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
