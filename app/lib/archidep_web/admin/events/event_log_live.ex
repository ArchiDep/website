defmodule ArchiDepWeb.Admin.Events.EventLogLive do
  use ArchiDepWeb, :live_view

  import ArchiDep.Helpers.PipeHelpers
  import ArchiDepWeb.Admin.Events.EventsComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Events

  @limit 15

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth
    events = Events.fetch_events(auth, limit: @limit)

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
    end

    socket
    |> assign(
      page_title: "#{gettext("ArchiDep")} > #{gettext("Event Log")}",
      oldest_event: List.last(events),
      newest_event: List.first(events),
      beginning?: true,
      end_of_timeline?: false
    )
    |> stream_configure(:events, dom_id: &"event-log-event-#{&1.id}")
    |> stream(:events, events)
    |> ok()
  end

  @impl LiveView

  def handle_event("next-page", _, socket) do
    {:noreply, paginate_events(socket, {:older_than, socket.assigns.oldest_event})}
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, paginate_events(socket)}
  end

  def handle_event("prev-page", _, socket) do
    {:noreply, paginate_events(socket, {:newer_than, socket.assigns.newest_event})}
  end

  defp paginate_events(socket, params \\ nil) do
    opts =
      case params do
        {:older_than, event} -> [older_than: event]
        {:newer_than, event} -> [newer_than: event]
        nil -> []
      end

    at = if Keyword.has_key?(opts, :newer_than), do: 0, else: -1

    events = Events.fetch_events(socket.assigns.auth, Keyword.put(opts, :limit, @limit))
    newest_event = List.first(events)
    oldest_event = List.last(events)
    ordered_events = if at == 0, do: Enum.reverse(events), else: events

    socket
    |> assign(:end_of_timeline?, at == -1 && length(events) < @limit)
    |> assign(:oldest_event, oldest_event)
    |> assign(:newest_event, newest_event)
    |> assign(:beginning?, opts != [])
    |> stream(:events, ordered_events, at: at, limit: @limit * 3 * at)
  end
end
