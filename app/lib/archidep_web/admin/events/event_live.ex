defmodule ArchiDepWeb.Admin.Events.EventLive do
  use ArchiDepWeb, :live_view

  import ArchiDep.Helpers.PipeHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Admin.Events.EventsComponents
  alias ArchiDep.Events

  @impl LiveView
  def mount(%{"id" => event_id}, _session, socket) do
    auth = socket.assigns.auth

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
    end

    case Events.fetch_event(auth, event_id) do
      {:ok, event} ->
        [{:ok, causation_event}, {:ok, correlation_event}] =
          Task.await_many([
            fetch_related_event(auth, event.id, event.causation_id),
            fetch_related_event(auth, event.id, event.correlation_id)
          ])

        socket
        |> assign(
          page_title: "#{gettext("Event Log")} · #{gettext("Admin")}",
          event: event,
          causation_event: causation_event,
          correlation_event: correlation_event
        )
        |> ok()

      {:error, :event_not_found} ->
        socket
        |> put_notification(Message.new(:error, gettext("Event not found")))
        |> push_navigate(to: ~p"/admin/events")
        |> ok()
    end
  end

  defp fetch_related_event(_auth, event_id, event_id), do: Task.completed({:ok, nil})

  defp fetch_related_event(auth, _event_id, other_event_id),
    do: Task.async(fn -> Events.fetch_event(auth, other_event_id) end)
end
