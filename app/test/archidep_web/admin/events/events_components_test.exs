defmodule ArchiDepWeb.Admin.Events.EventsComponentsTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Admin.Events.EventsComponents

  describe "event_context/1" do
    test "classifies an accounts event" do
      assert context_badge("archidep/accounts/user-logged-in") ==
               {"accounts", ["badge", "badge-primary"]}
    end

    test "classifies a servers event" do
      assert context_badge("archidep/servers/server-created") ==
               {"servers", ["badge", "badge-info"]}
    end

    test "classifies a students event" do
      assert context_badge("archidep/students/student-created") ==
               {"students", ["badge", "badge-secondary"]}
    end

    test "classifies any other archidep context with the accent badge" do
      assert context_badge("archidep/events/event-deleted") ==
               {"events", ["badge", "badge-accent"]}
    end

    test "falls back to the plain badge for an unrecognised type" do
      assert context_badge("legacy-event") == {"legacy-event", ["badge", "badge"]}
    end
  end

  describe "event_action/1" do
    test "marks a Switch edu-ID registration as an error" do
      assert action_badge("archidep/accounts/user-registered-with-switch-edu-id") ==
               {"user-registered-with-switch-edu-id",
                ["badge", "badge-error", "font-bold", "h-auto"]}
    end

    test "marks any other accounts action as a warning" do
      assert action_badge("archidep/accounts/user-logged-in") ==
               {"user-logged-in", ["badge", "badge-warning", "font-bold", "h-auto"]}
    end

    test "marks a created server as a success" do
      assert action_badge("archidep/servers/server-created") ==
               {"server-created", ["badge", "badge-success", "font-bold", "h-auto"]}
    end

    test "marks an updated server as a warning" do
      assert action_badge("archidep/servers/server-updated") ==
               {"server-updated", ["badge", "badge-warning", "font-bold", "h-auto"]}
    end

    test "marks any other servers action as informational" do
      assert action_badge("archidep/servers/server-deleted") ==
               {"server-deleted", ["badge", "badge-info", "font-bold", "h-auto"]}
    end

    test "marks a created class as a success" do
      assert action_badge("archidep/students/class-created") ==
               {"class-created", ["badge", "badge-success", "font-bold", "h-auto"]}
    end

    test "marks a created student as a success" do
      assert action_badge("archidep/students/student-created") ==
               {"student-created", ["badge", "badge-success", "font-bold", "h-auto"]}
    end

    test "marks an updated class as a warning" do
      assert action_badge("archidep/students/class-updated") ==
               {"class-updated", ["badge", "badge-warning", "font-bold", "h-auto"]}
    end

    test "marks a deleted class as an error" do
      assert action_badge("archidep/students/class-deleted") ==
               {"class-deleted", ["badge", "badge-error", "font-bold", "h-auto"]}
    end

    test "marks any other archidep action as informational" do
      assert action_badge("archidep/course/lesson-published") ==
               {"lesson-published", ["badge", "badge-info", "font-bold", "h-auto"]}
    end

    test "falls back to the plain badge for an unrecognised type" do
      assert action_badge("legacy-event") ==
               {"legacy-event", ["badge", "badge", "font-bold", "h-auto"]}
    end
  end

  describe "event_entity/1" do
    test "renders a class with its name" do
      entity = CourseFactory.build(:class, name: "Crypto 101")
      assert entity_badge(entity) == {"Crypto 101", ["flex", "items-center"]}
    end

    test "renders a server with its name or default" do
      entity = ServersFactory.build(:server, name: "web-01")
      assert entity_badge(entity) == {"web-01", ["flex", "items-center"]}
    end

    test "renders a preregistered user with its name" do
      entity = AccountsFactory.build(:preregistered_user, name: "Jane Doe")
      assert entity_badge(entity) == {"Jane Doe", ["flex", "items-center"]}
    end

    test "renders a student with its name" do
      entity = CourseFactory.build(:student, name: "John Roe")
      assert entity_badge(entity) == {"John Roe", ["flex", "items-center"]}
    end

    test "renders a user account by its preregistered name when preregistered" do
      entity =
        AccountsFactory.build(:user_account,
          username: "bob",
          switch_edu_id: nil,
          preregistered_user:
            AccountsFactory.build(:preregistered_user, name: "Bob Preregistered")
        )

      assert entity_badge(entity) == {"Bob Preregistered", ["flex", "items-center"]}
    end

    test "renders a user account by its Switch edu-ID name when not preregistered" do
      entity =
        AccountsFactory.build(:user_account,
          username: "bob",
          preregistered_user: nil,
          switch_edu_id:
            AccountsFactory.build(:switch_edu_id, first_name: "Bobby", last_name: "Tables")
        )

      assert entity_badge(entity) == {"Bobby Tables", ["flex", "items-center"]}
    end

    test "renders a user account by its username when it has no name" do
      entity =
        AccountsFactory.build(:user_account,
          username: "bob",
          preregistered_user: nil,
          switch_edu_id: nil
        )

      assert entity_badge(entity) == {"bob", ["flex", "items-center"]}
    end

    test "renders a deleted entity when there is none" do
      assert entity_badge(nil) == {"deleted", ["flex", "items-center", "text-base-content/50"]}
    end

    test "renders an unknown entity for any other value" do
      entity = CourseFactory.build(:expected_server_properties)
      assert entity_badge(entity) == {"unknown", ["flex", "items-center", "text-warning"]}
    end
  end

  defp context_badge(type) do
    rendered =
      render_component(&EventsComponents.event_context/1,
        event: EventsFactory.build(:stored_event, type: type)
      )

    badge_projection(rendered)
  end

  defp action_badge(type) do
    rendered =
      render_component(&EventsComponents.event_action/1,
        event: EventsFactory.build(:stored_event, type: type)
      )

    badge_projection(rendered)
  end

  defp entity_badge(entity) do
    html =
      render_component(&EventsComponents.event_entity/1,
        event: EventsFactory.build(:stored_event, entity: entity)
      )

    [badge] = find_html_elements(html, "span[class]")
    {html_element_text(html), class_tokens(badge)}
  end

  defp badge_projection(html) do
    [badge] = find_html_elements(html, "div")
    {html_element_text(badge), class_tokens(badge)}
  end

  defp class_tokens(element),
    do: element |> html_element_attribute("class") |> String.split() |> Enum.sort()
end
