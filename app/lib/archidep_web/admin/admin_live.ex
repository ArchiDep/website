defmodule ArchiDepWeb.Admin.AdminLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    active_classes = Course.list_active_classes(auth)

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
      :ok = PubSub.subscribe_classes()
    end

    socket
    |> assign(active_classes: active_classes)
    |> ok()
  end

  @impl LiveView
  def handle_info(
        {:class_created, created_class},
        %Socket{assigns: %{active_classes: active_classes}} = socket
      ) do
    if Class.active?(created_class, DateTime.utc_now()) do
      socket
      |> assign(:active_classes, active_classes |> add_class(created_class) |> sort_classes())
      |> noreply()
    else
      noreply(socket)
    end
  end

  @impl LiveView
  def handle_info(
        {:class_updated, %{id: id} = updated},
        %Socket{assigns: %{active_classes: active_classes}} = socket
      ) do
    if Class.active?(updated, DateTime.utc_now()) do
      socket
      |> assign(
        :active_classes,
        sort_classes(
          if(Enum.any?(active_classes, &(&1.id == id)),
            do: update_class(active_classes, updated),
            else: add_class(active_classes, updated)
          )
        )
      )
      |> noreply()
    else
      socket
      |> assign(active_classes: active_classes |> remove_class(updated) |> sort_classes())
      |> noreply()
    end
  end

  @impl LiveView
  def handle_info(
        {:class_deleted, deleted_class},
        %Socket{assigns: %{active_classes: active_classes}} = socket
      ),
      do:
        socket
        |> assign(
          :active_classes,
          active_classes
          |> remove_class(deleted_class)
          |> sort_classes()
        )
        |> noreply()

  defp add_class(classes, class), do: [class | classes]

  defp update_class(classes, %Class{id: id} = class) do
    Enum.map(classes, fn
      %Class{id: ^id} = c ->
        Class.refresh!(c, class)

      c ->
        c
    end)
  end

  defp remove_class(classes, class), do: Enum.reject(classes, fn c -> c.id == class.id end)

  defp sort_classes(classes),
    do: Enum.sort_by(classes, &{!&1.active, &1.end_date, &1.created_at, &1.name}, :desc)
end
