defmodule ArchiDepWeb.Admin.Classes.ClassesLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.DateFormatHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Servers
  alias ArchiDepWeb.Admin.Classes.NewClassDialogLive

  @impl true
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
      :ok = PubSub.subscribe_classes()
    end

    classes = Course.list_classes(auth)

    if connected?(socket) do
      for class <- classes do
        :ok = PubSub.subscribe_class(class.id)
        :ok = Servers.PubSub.subscribe_server_group(class.id)
      end
    end

    socket
    |> assign(
      page_title: "#{gettext("ArchiDep")} > #{gettext("Admin")} > #{gettext("Classes")}",
      classes: classes
    )
    |> ok()
  end

  @impl true
  def handle_params(_params, _url, socket), do: noreply(socket)

  @impl true
  def handle_info(
        {:class_created, created_class},
        %Socket{assigns: %{classes: classes}} = socket
      ) do
    :ok = PubSub.subscribe_class(created_class.id)

    socket
    |> assign(:classes, sort_classes([created_class | classes]))
    |> noreply()
  end

  @impl true
  def handle_info(
        {event, %{id: id} = updated},
        %Socket{assigns: %{classes: classes}} = socket
      )
      when event in [:class_updated, :server_group_updated],
      do:
        socket
        |> assign(
          :classes,
          classes
          |> Enum.map(fn
            %Class{id: ^id} = c ->
              Class.refresh!(c, updated)

            c ->
              c
          end)
          |> sort_classes()
        )
        |> noreply()

  @impl true
  def handle_info(
        {:class_deleted, deleted_class},
        %Socket{assigns: %{classes: classes}} = socket
      ) do
    :ok = PubSub.unsubscribe_class(deleted_class.id)
    :ok = Servers.PubSub.unsubscribe_server_group(deleted_class.id)

    socket
    |> assign(
      :classes,
      classes
      |> Enum.reject(fn c -> c.id == deleted_class.id end)
      |> sort_classes()
    )
    |> noreply()
  end

  defp sort_classes(classes),
    do: Enum.sort_by(classes, &{!&1.active, &1.end_date, &1.created_at, &1.name}, :desc)
end
