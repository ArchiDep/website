defmodule ArchiDepWeb.Dashboard.Components.WhatIsYourNameLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Course
  alias ArchiDepWeb.Dashboard.Components.WhatIsYourNameForm
  alias Phoenix.LiveView.JS

  @spec id() :: String.t()
  def id, do: "what-is-your-name"

  @impl true
  def update(assigns, socket) do
    student = assigns.student

    form =
      WhatIsYourNameForm.changeset(student, %{
        username: student.username
      })

    socket
    |> assign(assigns)
    |> assign(form: to_form(form, as: :student_config), change: false)
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"student_config" => params}, socket) when is_map(params) do
    auth = socket.assigns.auth
    student = socket.assigns.student
    form_changeset = WhatIsYourNameForm.changeset(student, params)

    with {:ok, form_data} <- Changeset.apply_action(form_changeset, :validate),
         data = WhatIsYourNameForm.to_data(form_data),
         {:ok, validated} <-
           Course.validate_student_config(auth, student.id, data) do
      socket
      |> assign(form: to_form(validated, as: :student_config, action: :validate))
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :student_config))}
    end
  end

  @impl true
  def handle_event("configure", %{"student_config" => params}, socket) when is_map(params) do
    auth = socket.assigns.auth
    student = socket.assigns.student
    form_changeset = WhatIsYourNameForm.changeset(student, params)

    with {:ok, form_data} <-
           Changeset.apply_action(form_changeset, :validate),
         data = WhatIsYourNameForm.to_data(form_data),
         {:ok, configured_student} <-
           Course.configure_student(auth, student.id, data) do
      socket
      |> send_notification(
        Message.new(:success, gettext("Hello, {name}!", name: configured_student.username))
      )
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        socket |> assign(form: to_form(changeset, as: :student_config)) |> noreply()
    end
  end
end
