defmodule ArchiDepWeb.Admin.Classes.EditClassExpectedServerPropertiesDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDepWeb.Servers.ServerPropertiesForm

  @base_id "edit-class-expected-server-properties-dialog"

  @spec id(Class.t()) :: String.t()
  def id(%Class{id: id}), do: "#{@base_id}-#{id}"

  @spec close(Class.t()) :: js
  def close(class), do: class |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket) do
    auth = assigns.auth
    class = assigns.class

    changeset =
      class.expected_server_properties
      |> ServerPropertiesForm.from()
      |> ServerPropertiesForm.changeset()

    socket
    |> assign(
      auth: auth,
      class: class,
      form: to_form(changeset, as: :expected_server_properties)
    )
    |> ok()
  end

  @impl LiveComponent

  def handle_event("closed", _params, socket) do
    class = socket.assigns.class

    changeset =
      class.expected_server_properties
      |> ServerPropertiesForm.from()
      |> ServerPropertiesForm.changeset()

    socket
    |> assign(form: to_form(changeset, as: :expected_server_properties))
    |> noreply()
  end

  def handle_event("validate", %{"expected_server_properties" => params}, socket) do
    auth = socket.assigns.auth
    class = socket.assigns.class

    changeset =
      class.expected_server_properties
      |> ServerPropertiesForm.from()
      |> ServerPropertiesForm.changeset(params)

    validate_dialog_form(
      :expected_server_properties,
      changeset,
      &Course.validate_expected_server_properties_for_class(
        auth,
        class.id,
        ServerPropertiesForm.to_data(&1)
      ),
      socket
    )
  end

  def handle_event("update", %{"expected_server_properties" => params}, socket) do
    auth = socket.assigns.auth
    class = socket.assigns.class

    changeset =
      class.expected_server_properties
      |> ServerPropertiesForm.from()
      |> ServerPropertiesForm.changeset(params)

    with {:ok, form_data} <-
           Changeset.apply_action(
             changeset,
             :validate
           ),
         {:ok, _updated_props} <-
           Course.update_expected_server_properties_for_class(
             auth,
             class.id,
             ServerPropertiesForm.to_data(form_data)
           ) do
      socket
      |> send_notification(
        Message.new(
          :success,
          gettext("Updated expected server properties for {class}", class: class.name)
        )
      )
      |> push_event("execute-action", %{to: "##{id(class)}", action: "close"})
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
