defmodule ArchiDepWeb.Admin.EventLogLive do
  use ArchiDepWeb, :live_view

  import ArchiDep.Helpers.PipeHelpers
  import ArchiDepWeb.Events.EventsComponents
  alias ArchiDep.Events

  @limit 10
  @load_more_limit 20

  @impl LiveView
  def mount(_params, _session, socket) do
    events = Events.fetch_latest_events(socket.assigns.auth, limit: @limit)

    socket
    |> assign(
      page_title: "ArchiDep > Event Log",
      oldest_event: List.last(events),
      newest_event: nil,
      before: nil,
      after: nil,
      end_of_timeline?: false
    )
    |> stream_configure(:events, dom_id: &"event-log-event-#{&1.id}")
    |> stream(:events, events)
    |> ok()
  end

  @impl LiveView

  def handle_event("next-page", _, socket) do
    {:noreply, paginate_events(socket, before: socket.assigns.oldest_event)}
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, paginate_events(socket, [])}
  end

  def handle_event("prev-page", _, socket) do
    {:noreply, paginate_events(socket, after: socket.assigns.newest_event)}
  end

  defp paginate_events(socket, opts) do
    at = if Keyword.has_key?(opts, :after), do: 0, else: -1
    events = Events.fetch_latest_events(socket.assigns.auth, Keyword.put(opts, :limit, @limit))
    oldest_event = if at == -1, do: List.last(events), else: nil
    newest_event = if at == 0, do: List.first(events), else: nil

    case events do
      [] ->
        socket
        |> assign(:end_of_timeline?, at == -1)
        |> assign(:before, Keyword.get(opts, :before))
        |> assign(:after, Keyword.get(opts, :after))
        |> assign(:oldest_event, oldest_event)
        |> assign(:newest_event, newest_event)
        |> stream(:events, events, at: at, limit: @limit * 3 * at)

      [_ | _] ->
        socket
        |> assign(:end_of_timeline?, false)
        |> assign(:before, Keyword.get(opts, :before))
        |> assign(:after, Keyword.get(opts, :after))
        |> assign(:oldest_event, oldest_event)
        |> assign(:newest_event, newest_event)
        |> stream(:events, events, at: at, limit: @limit * 3 * at)
    end
  end
end
