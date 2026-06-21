defmodule ArchiDepWeb.Admin.Events.EventLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Events
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory

  setup :verify_on_exit!

  describe "as a root user" do
    setup :register_and_log_in_root

    test "render the event detail page with its immediate and root causes", %{
      conn: conn,
      auth: auth
    } do
      causation =
        EventsFactory.build(:stored_event, type: "archidep/accounts/user-logged-in")

      correlation =
        EventsFactory.build(:stored_event, type: "archidep/servers/server-created")

      event =
        EventsFactory.build(:stored_event,
          type: "archidep/students/class-created",
          stream: "students:class:fixed-stream",
          version: 3,
          occurred_at: ~U[2026-06-19 08:30:00Z],
          initiator: "accounts/user-accounts/fixed-initiator",
          data: %{"name" => "Crypto 101"},
          meta: %{"ip" => "1.2.3.4"},
          entity: CourseFactory.build(:class, name: "Crypto 101"),
          causation_id: causation.id,
          correlation_id: correlation.id
        )

      stub(Events.ContextMock, :fetch_event, fn ^auth, id ->
        cond do
          id == event.id -> {:ok, event}
          id == causation.id -> {:ok, causation}
          id == correlation.id -> {:ok, correlation}
        end
      end)

      {:ok, _view, html} = live(conn, "/admin/events/#{event.id}")

      assert_html_title(html, "Event Log · Admin · ArchiDep")

      assert page_projection(html) == %{
               data_display: [
                 {"Event ID", event.id},
                 {"Context & type", ["students", "class-created"]},
                 {"Stream", "students:class:fixed-stream"},
                 {"Version", "3"},
                 {"Occurred at", "Fri, June 19, 2026 at 08:30:00"},
                 {"Initiator", "accounts/user-accounts/fixed-initiator"},
                 {"Immediate cause",
                  {["accounts", "user-logged-in"], "/admin/events/#{causation.id}"}},
                 {"Root cause",
                  {["servers", "server-created"], "/admin/events/#{correlation.id}"}}
               ],
               data: normalize_json(%{"name" => "Crypto 101"}),
               metadata: normalize_json(%{"ip" => "1.2.3.4"})
             }
    end

    test "omit the cause rows when the event is its own cause", %{conn: conn, auth: auth} do
      event =
        EventsFactory.build(:stored_event,
          type: "archidep/students/class-created",
          stream: "students:class:solo-stream",
          version: 1,
          occurred_at: ~U[2026-06-18 07:15:00Z],
          initiator: "accounts/user-accounts/solo-initiator",
          data: %{},
          meta: %{},
          entity: CourseFactory.build(:class, name: "Solo")
        )

      id = event.id

      # Pinning exactly two calls (one per mount) proves the immediate- and
      # root-cause fetches are skipped when the event references itself.
      expect(Events.ContextMock, :fetch_event, 2, fn ^auth, ^id -> {:ok, event} end)

      {:ok, _view, html} = live(conn, "/admin/events/#{event.id}")

      assert page_projection(html) == %{
               data_display: [
                 {"Event ID", event.id},
                 {"Context & type", ["students", "class-created"]},
                 {"Stream", "students:class:solo-stream"},
                 {"Version", "1"},
                 {"Occurred at", "Thu, June 18, 2026 at 07:15:00"},
                 {"Initiator", "accounts/user-accounts/solo-initiator"}
               ],
               data: normalize_json(%{}),
               metadata: normalize_json(%{})
             }
    end

    test "redirect to the event log when the event is not found", %{conn: conn, auth: auth} do
      stub(Events.ContextMock, :fetch_event, fn ^auth, _id -> {:error, :event_not_found} end)

      assert {:error, {:live_redirect, %{flash: flash, to: "/admin/events"}}} =
               live(conn, "/admin/events/#{UUID.generate()}")

      assert redirect_notifications(flash) == [{:error, gettext("Event not found")}]
    end
  end

  test "accessing an event redirects to the login page without authentication", %{conn: conn} do
    assert_live_anonymous_user_redirected_to_login(conn, "/admin/events/#{UUID.generate()}")
  end

  # Projects the whole detail page: the data-display rows plus the JSON data and
  # metadata panels, so a single assertion pins everything the page renders.
  defp page_projection(html) do
    [data_block, metadata_block] = find_html_elements(html, "pre")

    %{
      data_display: data_display_rows(html),
      data: html_element_text(data_block),
      metadata: html_element_text(metadata_block)
    }
  end

  defp data_display_rows(html) do
    html
    |> find_html_elements("dl > div")
    |> Enum.map(fn row ->
      [title] = row |> find_html_elements("dt") |> Enum.map(&html_element_text/1)
      [dd] = find_html_elements(row, "dd")
      {title, dd_value(dd)}
    end)
  end

  # The context-and-type and cause cells render their values as adjacent badges
  # with no separating text, so they project to the list of badge labels (the
  # boundary between context and action would otherwise be lost). A cause cell
  # also wraps its badges in a link, so its target is projected alongside.
  defp dd_value(dd) do
    badges = dd |> find_html_elements(".badge") |> Enum.map(&html_element_text/1)

    case {badges, find_html_elements(dd, "a")} do
      {[], _no_badges} -> html_element_text(dd)
      {labels, [link]} -> {labels, html_element_attribute(link, "href")}
      {labels, []} -> labels
    end
  end

  defp normalize_json(value),
    do: value |> Jason.encode!(pretty: true) |> String.replace(~r/\s+/, " ") |> String.trim()

  defp redirect_notifications(flash),
    do:
      flash
      |> Map.values()
      |> Enum.map(fn notification -> {notification.type, notification.message} end)
end
