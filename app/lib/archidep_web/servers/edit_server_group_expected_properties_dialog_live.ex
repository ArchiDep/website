defmodule ArchiDepWeb.Servers.EditServerGroupExpectedPropertiesDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDepWeb.Servers.ServerPropertiesForm

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
      group
      |> ServerGroup.expected_server_properties()
      |> ServerPropertiesForm.from()
      |> ServerPropertiesForm.changeset()

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
      group
      |> ServerGroup.expected_server_properties()
      |> ServerPropertiesForm.from()
      |> ServerPropertiesForm.changeset()

    socket
    |> assign(form: to_form(changeset, as: :expected_server_properties))
    |> noreply()
  end

  def handle_event("validate", %{"expected_server_properties" => params}, socket) do
    auth = socket.assigns.auth
    group = socket.assigns.group

    changeset =
      group
      |> ServerGroup.expected_server_properties()
      |> ServerPropertiesForm.from()
      |> ServerPropertiesForm.changeset(params)

    validate_dialog_form(
      :expected_server_properties,
      changeset,
      &Servers.validate_server_group_expected_properties(
        auth,
        group.id,
        ServerPropertiesForm.to_data(&1)
      ),
      socket
    )
  end

  def handle_event("update", %{"expected_server_properties" => params}, socket) do
    auth = socket.assigns.auth
    group = socket.assigns.group

    changeset =
      group
      |> ServerGroup.expected_server_properties()
      |> ServerPropertiesForm.from()
      |> ServerPropertiesForm.changeset(params)

    with {:ok, form_data} <-
           Changeset.apply_action(
             changeset,
             :validate
           ),
         {:ok, _updated_props} <-
           Servers.update_server_group_expected_properties(
             auth,
             group.id,
             ServerPropertiesForm.to_data(form_data)
           ) do
      socket
      |> send_notification(
        Message.new(
          :success,
          gettext("Updated expected server properties for {group}", group: group.name)
        )
      )
      |> push_event("execute-action", %{to: "##{id(group)}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        socket
        |> send_notification(Message.new(:error, gettext("The form is invalid.")))
        |> assign(form: to_form(changeset, as: :expected_server_properties))
        |> noreply()
    end
  end
end
