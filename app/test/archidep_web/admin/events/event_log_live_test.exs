defmodule ArchiDepWeb.Admin.Events.EventLogLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Events
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory

  @path "/admin/events"
  # Mirrors the @limit module attribute of the live view under test: a full page
  # leaves more to fetch, a shorter page reaches the end of the timeline.
  @limit 50

  setup :verify_on_exit!

  describe "as a root user" do
    setup :register_and_log_in_root

    test "render the event log over a static (disconnected) request", %{conn: conn, auth: auth} do
      account =
        AccountsFactory.build(:user_account,
          username: "bob",
          switch_edu_id: nil,
          preregistered_user: nil
        )

      class = CourseFactory.build(:class, name: "Crypto 101")

      events = [
        EventsFactory.build(:stored_event,
          type: "archidep/accounts/user-logged-in",
          entity: account,
          occurred_at: ~U[2026-06-20 09:00:00Z]
        ),
        EventsFactory.build(:stored_event,
          type: "archidep/students/class-created",
          entity: class,
          occurred_at: ~U[2026-06-19 08:30:00Z]
        ),
        EventsFactory.build(:stored_event,
          type: "archidep/servers/server-created",
          entity: nil,
          occurred_at: ~U[2026-06-18 07:15:00Z]
        )
      ]

      expect(Events.ContextMock, :fetch_events, 1, fn ^auth, [limit: @limit] -> events end)

      html =
        conn
        |> get(@path)
        |> html_response(200)

      assert_html_title(html, "Event Log · Admin · ArchiDep")

      assert page_projection(html) == %{
               rows: [
                 {"accounts", "user-logged-in", "bob", "Sat, June 20, 2026 at 09:00:00"},
                 {"students", "class-created", "Crypto 101", "Fri, June 19, 2026 at 08:30:00"},
                 {"servers", "server-created", "deleted", "Thu, June 18, 2026 at 07:15:00"}
               ],
               pagination: end_of_timeline_at_the_beginning()
             }
    end

    test "render an empty event log", %{conn: conn, auth: auth} do
      expect(Events.ContextMock, :fetch_events, 2, fn ^auth, [limit: @limit] -> [] end)

      {:ok, _view, html} = live(conn, @path)

      assert page_projection(html) == %{
               rows: [],
               pagination: end_of_timeline_at_the_beginning()
             }
    end
  end

  describe "pagination" do
    setup :register_and_log_in_root

    test "the first page offers the next page and hides the first/previous controls", %{
      conn: conn,
      auth: auth
    } do
      expect(Events.ContextMock, :fetch_events, 2, fn ^auth, [limit: @limit] ->
        full_page(~U[2026-06-20 09:00:00Z])
      end)

      {:ok, _view, html} = live(conn, @path)

      assert page_projection(html) == %{
               rows: full_page_rows("Sat, June 20, 2026 at 09:00:00"),
               pagination: %{
                 first: false,
                 previous: false,
                 next: true,
                 beginning_of_time_message: []
               }
             }
    end

    test "the next page is fetched older than the oldest event currently shown", %{
      conn: conn,
      auth: auth
    } do
      first_page = full_page(~U[2026-06-20 09:00:00Z])
      oldest = List.last(first_page)
      cursor = {oldest.id, oldest.occurred_at}
      next_page = [single_server_event("web-01", ~U[2026-05-10 06:00:00Z])]

      expect(Events.ContextMock, :fetch_events, 2, fn ^auth, [limit: @limit] -> first_page end)

      expect(Events.ContextMock, :fetch_events, 1, fn ^auth,
                                                      [limit: @limit, older_than: ^cursor] ->
        next_page
      end)

      {:ok, view, first_html} = live(conn, @path)

      assert page_projection(first_html) == %{
               rows: full_page_rows("Sat, June 20, 2026 at 09:00:00"),
               pagination: %{
                 first: false,
                 previous: false,
                 next: true,
                 beginning_of_time_message: []
               }
             }

      next_html =
        view
        |> element(~s(button[phx-click="next-page"]))
        |> render_click()

      assert page_projection(next_html) == %{
               rows: [{"servers", "server-created", "web-01", "Sun, May 10, 2026 at 06:00:00"}],
               pagination: %{
                 first: true,
                 previous: true,
                 next: false,
                 beginning_of_time_message: ["This is the beginning of time."]
               }
             }
    end

    test "the previous page is fetched newer than the newest event currently shown", %{
      conn: conn,
      auth: auth
    } do
      first_page = full_page(~U[2026-06-20 09:00:00Z])
      second_page = full_page(~U[2026-06-19 08:00:00Z])
      oldest_of_first = List.last(first_page)
      next_cursor = {oldest_of_first.id, oldest_of_first.occurred_at}
      newest_of_second = List.first(second_page)
      previous_cursor = {newest_of_second.id, newest_of_second.occurred_at}
      previous_page = [single_server_event("db-01", ~U[2026-07-01 10:00:00Z])]

      expect(Events.ContextMock, :fetch_events, 2, fn ^auth, [limit: @limit] -> first_page end)

      expect(Events.ContextMock, :fetch_events, 1, fn ^auth,
                                                      [limit: @limit, older_than: ^next_cursor] ->
        second_page
      end)

      expect(Events.ContextMock, :fetch_events, 1, fn ^auth,
                                                      [
                                                        limit: @limit,
                                                        newer_than: ^previous_cursor
                                                      ] ->
        previous_page
      end)

      {:ok, view, _first_html} = live(conn, @path)

      second_html =
        view
        |> element(~s(button[phx-click="next-page"]))
        |> render_click()

      assert page_projection(second_html) == %{
               rows: full_page_rows("Fri, June 19, 2026 at 08:00:00"),
               pagination: %{
                 first: true,
                 previous: true,
                 next: true,
                 beginning_of_time_message: []
               }
             }

      previous_html =
        view
        |> element(~s(button[phx-click="previous-page"]))
        |> render_click()

      assert page_projection(previous_html) == %{
               rows: [{"servers", "server-created", "db-01", "Wed, July 01, 2026 at 10:00:00"}],
               pagination: %{
                 first: false,
                 previous: false,
                 next: true,
                 beginning_of_time_message: []
               }
             }
    end
  end

  test "accessing the event log redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(conn, @path)
  end

  defp full_page(occurred_at) do
    Enum.map(1..@limit, fn _index ->
      EventsFactory.build(:stored_event,
        type: "archidep/servers/server-created",
        entity: nil,
        occurred_at: occurred_at
      )
    end)
  end

  # A full page is built from interchangeable events, so its rendered table is
  # the same row repeated @limit times; the per-page timestamp distinguishes one
  # full page from another across a navigation.
  defp full_page_rows(occurred_at_text),
    do: List.duplicate({"servers", "server-created", "deleted", occurred_at_text}, @limit)

  defp single_server_event(name, occurred_at),
    do:
      EventsFactory.build(:stored_event,
        type: "archidep/servers/server-created",
        entity: ServersFactory.build(:server, name: name),
        occurred_at: occurred_at
      )

  defp end_of_timeline_at_the_beginning,
    do: %{
      first: false,
      previous: false,
      next: false,
      beginning_of_time_message: ["This is the beginning of time."]
    }

  defp page_projection(html),
    do: %{rows: event_log_table(html), pagination: pagination_state(html)}

  defp event_log_table(html) do
    html
    |> find_html_elements("tbody tr")
    |> Enum.map(fn row ->
      [context | _action_and_entity] = find_html_elements(row, "td:nth-child(1) .badge")
      [action] = find_html_elements(row, "td:nth-child(2) .badge")
      [entity] = find_html_elements(row, "td:nth-child(3)")
      [occurred_at] = find_html_elements(row, "td:nth-child(4)")

      {html_element_text(context), html_element_text(action), html_element_text(entity),
       html_element_text(occurred_at)}
    end)
  end

  defp pagination_state(html) do
    %{
      first: control_present?(html, "first-page"),
      previous: control_present?(html, "previous-page"),
      next: control_present?(html, "next-page"),
      beginning_of_time_message:
        html |> find_html_elements("p.italic.text-info") |> Enum.map(&html_element_text/1)
    }
  end

  defp control_present?(html, event),
    do: find_html_elements(html, ~s(button[phx-click="#{event}"])) != []
end
