defmodule ArchiDepWeb.Admin.Events.EventLogLive do
  use ArchiDepWeb, :live_view

  import ArchiDep.Helpers.PipeHelpers
  import ArchiDepWeb.Admin.Events.EventsComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Events

  @limit 20

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth
    # events = Events.fetch_events(auth, limit: @limit)

    # IO.puts("@@@@@@@@@@@@@@ initial events")
    # log_events(events)

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
    end

    socket
    |> assign(
      page_title: "#{gettext("ArchiDep")} > #{gettext("Event Log")}",
      # oldest_event: List.last(events),
      # newest_event: List.first(events),
      page: 1,
      per_page: @limit,
      # beginning?: true,
      end_of_timeline?: false
    )
    |> stream_configure(:events, dom_id: &"event-log-event-#{&1.id}")
    |> paginate_events(1)
    # |> stream(:events, events)
    |> ok()
  end

  @impl LiveView

  def handle_event("next-page", params, socket) do
    IO.puts("@@@@@@@@@@@@@@ next page #{socket.assigns.page + 1} #{inspect(params)}")
    # {:noreply, paginate_events(socket, {:older_than, socket.assigns.oldest_event})}
    socket
    |> paginate_events(socket.assigns.page + 1)
    |> noreply()
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    IO.puts("@@@@@@@@@@@@@@ prev page (overran)")
    # {:noreply, paginate_events(socket)}
    socket
    |> paginate_events(1)
    |> noreply()
  end

  def handle_event("prev-page", _params, socket) do
    IO.puts("@@@@@@@@@@@@@@ prev page #{socket.assigns.page - 1}")
    # {:noreply, paginate_events(socket, {:newer_than, socket.assigns.newest_event})}
    if socket.assigns.page > 1 do
      socket
      |> paginate_events(socket.assigns.page - 1)
      |> noreply()
    else
      noreply(socket)
    end
  end

  defp paginate_events(socket, new_page) when new_page >= 1 do
    %{per_page: per_page, page: cur_page} = socket.assigns

    events =
      if new_page >= 20 do
        []
      else
        ((new_page - 1) * per_page + 1)
        |> Range.new(new_page * per_page)
        |> Enum.map(&%{id: "#{new_page}.#{&1}"})
      end

    {events, at, limit, reset} =
      if new_page >= cur_page do
        IO.puts("@@@ append #{length(events)} events at the bottom: #{inspect(events)}")
        {events, -1, per_page * 3 * -1, false}
      else
        IO.puts("@@@ insert #{length(events)} events at the top: #{inspect(events)}")
        {Enum.reverse(events), 0, per_page * 3, new_page == 1}
      end

    case events do
      [] ->
        assign(socket, end_of_timeline?: at == -1)

      [_ | _] = events ->
        socket
        # |> assign(beginning?: new_page == 1)
        |> assign(end_of_timeline?: false)
        |> assign(:page, new_page)
        |> stream(:events, events, at: at, limit: limit, reset: reset)
    end
  end

  # defp paginate_events(socket, params \\ nil) do
  #   opts =
  #     case params do
  #       {:older_than, event} -> [older_than: event]
  #       {:newer_than, event} -> [newer_than: event]
  #       nil -> []
  #     end

  #   at = if Keyword.has_key?(opts, :newer_than), do: 0, else: -1

  #   events = Events.fetch_events(socket.assigns.auth, Keyword.put(opts, :limit, @limit))
  #   newest_event = List.first(events)
  #   oldest_event = List.last(events)
  #   ordered_events = if at == 0, do: Enum.reverse(events), else: events

  #   log_events(ordered_events)

  #   socket
  #   |> assign(:end_of_timeline?, at == -1 && length(events) < @limit)
  #   |> assign(:oldest_event, oldest_event)
  #   |> assign(:newest_event, newest_event)
  #   |> assign(:beginning?, opts != [])
  #   |> stream(:events, ordered_events, at: at, limit: @limit * 3 * at)
  # end

  defp log_events(events) do
    for event <- events do
      IO.puts(
        "@@@@@@@ - #{DateTime.to_iso8601(event.occurred_at)} #{String.slice(event.id, 0, 5)} #{event.type}"
      )
    end
  end
end
