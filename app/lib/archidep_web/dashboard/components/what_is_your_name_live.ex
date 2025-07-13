defmodule ArchiDepWeb.Dashboard.Components.WhatIsYourNameLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Servers
  alias ArchiDepWeb.Dashboard.Components.WhatIsYourNameForm
  alias Phoenix.LiveView.JS

  @spec id() :: String.t()
  def id, do: "what-is-your-name"

  @impl true
  def update(assigns, socket) do
    student = assigns.student
    server_group_member = assigns.server_group_member

    form =
      WhatIsYourNameForm.changeset(server_group_member, %{
        username: student.suggested_username
      })

    socket
    |> assign(assigns)
    |> assign(form: to_form(form, as: :server_group_member), change: false)
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"server_group_member" => params}, socket) when is_map(params) do
    auth = socket.assigns.auth
    server_group_member = socket.assigns.server_group_member
    form_changeset = WhatIsYourNameForm.changeset(server_group_member, params)

    with {:ok, form_data} <- Changeset.apply_action(form_changeset, :validate),
         data = WhatIsYourNameForm.to_data(form_data),
         {:ok, validated} <-
           Servers.validate_server_group_member_config(auth, server_group_member.id, data) do
      socket
      |> assign(form: to_form(validated, as: :server_group_member, action: :validate))
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :server_group_member))}
    end
  end

  @impl true
  def handle_event("configure", %{"server_group_member" => params}, socket) when is_map(params) do
    auth = socket.assigns.auth
    server_group_member = socket.assigns.server_group_member
    form_changeset = WhatIsYourNameForm.changeset(server_group_member, params)

    with {:ok, form_data} <-
           Changeset.apply_action(form_changeset, :validate),
         data = WhatIsYourNameForm.to_data(form_data),
         {:ok, configured_member} <-
           Servers.configure_server_group_member(auth, server_group_member.id, data) do
      socket
      |> send_notification(
        Message.new(:success, gettext("Hello, {name}!", name: configured_member.username))
      )
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        socket |> assign(form: to_form(changeset, as: :server_group_member)) |> noreply()
    end
  end
end
