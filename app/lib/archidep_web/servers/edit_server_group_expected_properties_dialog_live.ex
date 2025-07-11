defmodule ArchiDepWeb.Servers.EditServerGroupExpectedPropertiesDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.Schemas.ServerGroup

  @base_id "edit-server-group-expected-properties-dialog"

  @spec id(ServerGroup.t()) :: String.t()
  def id(%ServerGroup{id: id}), do: "#{@base_id}-#{id}"

  @spec close(ServerGroup.t()) :: js
  def close(group), do: group |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket) do
    auth = assigns.auth
    group = assigns.group

    changeset =
      if group.expected_server_properties == nil do
        ServerProperties.blank(group.id)
      else
        ServerProperties.update(group.expected_server_properties)
      end

    socket
    |> assign(
      auth: auth,
      group: group,
      form: to_form(changeset, as: :expected_server_properties)
    )
    |> ok()
  end

  @impl LiveComponent

  def handle_event("closed", _params, socket) do
    group = socket.assigns.group

    changeset =
      if group.expected_server_properties do
        ServerProperties.update(group.expected_server_properties)
      else
        ServerProperties.blank(group.id)
      end

    socket
    |> assign(form: to_form(changeset, as: :expected_server_properties))
    |> noreply()
  end

  # def handle_event("validate", %{"expected_server_properties" => params}, socket) do
  #   auth = socket.assigns.auth
  #   server = socket.assigns.server

  #   validate_dialog_form(
  #     :server,
  #     ServerForm.update_changeset(server, params),
  #     &Servers.validate_existing_server(
  #       auth,
  #       server.id,
  #       ServerForm.to_update_data(&1)
  #     ),
  #     socket
  #   )
  # end

  # def handle_event("update", %{"server" => params}, socket) do
  #   auth = socket.assigns.auth
  #   server = socket.assigns.server

  #   with {:ok, form_data} <-
  #          Changeset.apply_action(
  #            ServerForm.update_changeset(server, params),
  #            :validate
  #          ),
  #        {:ok, updated_server} <-
  #          Servers.update_server(auth, server.id, ServerForm.to_update_data(form_data)) do
  #     socket
  #     |> send_notification(
  #       Message.new(
  #         :success,
  #         gettext("Updated server {server}", server: Server.name_or_default(updated_server))
  #       )
  #     )
  #     |> push_event("execute-action", %{to: "##{id(server)}", action: "close"})
  #     |> noreply()
  #   else
  #     {:error, %Changeset{} = changeset} ->
  #       socket
  #       |> send_notification(Message.new(:error, gettext("The form is invalid.")))
  #       |> assign(form: to_form(changeset, as: :server))
  #       |> noreply()
  #   end
  # end
end
