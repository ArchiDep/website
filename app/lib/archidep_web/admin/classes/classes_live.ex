defmodule ArchiDepWeb.Admin.Classes.ClassesLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.DateFormatHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Students
  alias ArchiDep.Students.PubSub
  alias ArchiDepWeb.Admin.Classes.NewClassDialogLive

  @impl true
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
      :ok = PubSub.subscribe_classes()
    end

    classes = Students.list_classes(auth)

    for class <- classes do
      :ok = PubSub.subscribe_class(class.id)
    end

    socket
    |> assign(
      page_title: "ArchiDep > Admin > Classes",
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
        {:class_updated, updated_class},
        %Socket{assigns: %{classes: classes}} = socket
      ),
      do:
        socket
        |> assign(
          :classes,
          classes
          |> Enum.map(fn c ->
            if c.id == updated_class.id do
              updated_class
            else
              c
            end
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
