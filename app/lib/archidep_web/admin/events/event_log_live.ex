defmodule ArchiDepWeb.Admin.Events.EventLogLive do
  use ArchiDepWeb, :live_view

  import ArchiDep.Helpers.PipeHelpers
  import ArchiDepWeb.Admin.Events.EventsComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Events
  alias ArchiDep.Events.Store.StoredEvent
  alias Phoenix.LiveView.JS

  @limit 50

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
    end

    socket
    |> assign(
      page_title: "#{gettext("Event Log")} · #{gettext("Admin")}",
      events: []
    )
    |> paginate_events(:first)
    |> ok()
  end

  @impl LiveView

  def handle_event("next-page", _params, socket) do
    socket
    |> paginate_events(:next)
    |> noreply()
  end

  def handle_event("first-page", _params, socket) do
    socket
    |> paginate_events(:first)
    |> noreply()
  end

  def handle_event("previous-page", _params, socket) do
    socket
    |> paginate_events(:previous)
    |> noreply()
  end

  defp paginate_events(socket, page) when page in [:first, :next, :previous] do
    auth = socket.assigns.auth
    previous_events = socket.assigns.events
    oldest_event = List.last(previous_events)
    newest_event = List.first(previous_events)

    fetch_opts =
      case {page, oldest_event, newest_event} do
        {:next, nil, nil} -> [limit: @limit]
        {:next, oldest, _newest} -> [limit: @limit, older_than: event_ref(oldest)]
        {:previous, _oldest, newest} -> [limit: @limit, newer_than: event_ref(newest)]
        {:first, _oldest, _newest} -> [limit: @limit]
      end

    events = Events.fetch_events(auth, fetch_opts)

    assign(socket,
      events: events,
      oldest_event: oldest_event,
      newest_event: newest_event,
      beginning?: page == :first or (page == :previous and length(events) < @limit),
      end_of_timeline?: (page == :first or page == :next) and length(events) < @limit
    )
  end

  defp event_ref(%StoredEvent{id: id, occurred_at: occurred_at}), do: {id, occurred_at}
end
