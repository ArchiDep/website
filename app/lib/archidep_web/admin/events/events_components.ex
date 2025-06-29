defmodule ArchiDepWeb.Admin.Events.EventsComponents do
  @moduledoc """
  Component used to display event-related data.
  """

  use ArchiDepWeb, :component

  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student

  @spec event_context(map) :: Phoenix.LiveView.Rendered.t()

  attr(:event, StoredEvent, required: true)

  def event_context(assigns) when is_map(assigns) do
    assigns = assign(assigns, event_context_and_class(assigns.event))

    ~H"""
    <div class={"badge #{@class}"}>{@context}</div>
    """
  end

  defp event_context_and_class(%StoredEvent{type: type} = event) when is_struct(event),
    do: type |> String.split("/") |> event_context_and_class()

  defp event_context_and_class(["archidep", "accounts", _action]),
    do: [context: "accounts", class: "badge-primary"]

  defp event_context_and_class(["archidep", "servers", _action]),
    do: [context: "servers", class: "badge-info"]

  defp event_context_and_class(["archidep", "students", _action]),
    do: [context: "students", class: "badge-secondary"]

  defp event_context_and_class(["archidep", context, _action]),
    do: [context: context, class: "badge-accent"]

  defp event_context_and_class(parts), do: [context: Enum.join(parts, "/"), class: "badge"]

  @spec event_action(map) :: Phoenix.LiveView.Rendered.t()

  attr(:event, StoredEvent, required: true)
  attr(:extra_class, :string, default: nil)

  def event_action(assigns) when is_map(assigns) do
    assigns = assign(assigns, event_action_and_class(assigns.event))

    ~H"""
    <div class={"badge #{@class} font-bold h-auto #{@extra_class}"}>{@action}</div>
    """
  end

  defp event_action_and_class(%StoredEvent{type: type} = event) when is_struct(event),
    do: type |> String.split("/") |> event_action_and_class()

  defp event_action_and_class(["archidep", "accounts", action])
       when action in ["user-registered-with-switch-edu-id"],
       do: [action: action, class: "badge-error"]

  defp event_action_and_class(["archidep", "accounts", action]),
    do: [action: action, class: "badge-warning"]

  defp event_action_and_class(["archidep", "servers", action])
       when action in ["server-created"],
       do: [action: action, class: "badge-success"]

  defp event_action_and_class(["archidep", "servers", action])
       when action in ["server-updated"],
       do: [action: action, class: "badge-warning"]

  defp event_action_and_class(["archidep", "students", action])
       when action in ["class-created", "student-created"],
       do: [action: action, class: "badge-success"]

  defp event_action_and_class(["archidep", "students", action])
       when action in ["class-updated"],
       do: [action: action, class: "badge-warning"]

  defp event_action_and_class(["archidep", "students", action])
       when action in ["class-deleted"],
       do: [action: action, class: "badge-error"]

  defp event_action_and_class(["archidep", _context, action]),
    do: [action: action, class: "badge-info"]

  defp event_action_and_class(parts), do: [action: Enum.join(parts, "/"), class: "badge"]

  @spec event_entity(map) :: Phoenix.LiveView.Rendered.t()

  attr(:event, StoredEvent, required: true)
  attr(:extra_class, :string, default: nil)

  def event_entity(assigns) when is_map(assigns) do
    case assigns.event.entity do
      %Class{name: name} ->
        assigns = assign(assigns, :name, name)

        ~H"""
        <span class={"flex items-center #{@extra_class}"}>
          <Heroicons.academic_cap solid class="size-6 mr-1" />
          <span>{@name}</span>
        </span>
        """

      %Server{} = server ->
        assigns = assign(assigns, :server, server)

        ~H"""
        <span class={"flex items-center #{@extra_class}"}>
          <Heroicons.server solid class="size-6 mr-1" />
          <span>{Server.name_or_default(@server)}</span>
        </span>
        """

      %Student{name: name} ->
        assigns = assign(assigns, :name, name)

        ~H"""
        <span class={"flex items-center #{@extra_class}"}>
          <Heroicons.user solid class="size-6 mr-1" />
          <span>{@name}</span>
        </span>
        """

      %UserAccount{username: username} ->
        assigns = assign(assigns, :username, username)

        ~H"""
        <span class={"flex items-center #{@extra_class}"}>
          <Heroicons.user solid class="size-6 mr-1" />
          <span>{@username}</span>
        </span>
        """

      nil ->
        ~H"""
        <span class={"flex items-center text-base-content/50 #{@extra_class}"}>
          <Heroicons.trash class="size-6 me-1" />
          <span>{gettext("deleted")}</span>
        </span>
        """

      _anything_else ->
        ~H"""
        <span class={"flex items-center text-warning #{@extra_class}"}>
          <Heroicons.question_mark_circle solid class="size-6 me-1" />
          <span>{gettext("unknown")}</span>
        </span>
        """
    end
  end
end
