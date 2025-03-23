defmodule ArchiDepWeb.Events.EventsComponents do
  @moduledoc """
  Component used to display event-related data.
  """

  use ArchiDepWeb, :component

  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Events.Store.StoredEvent

  @spec event_context(map) :: Phoenix.LiveView.Rendered.t()

  attr(:event, StoredEvent, required: true)

  def event_context(assigns) when is_map(assigns) do
    assigns = assign(assigns, event_context_and_class(assigns.event))

    ~H"""
    <div class={@class}>{@context}</div>
    """
  end

  defp event_context_and_class(%StoredEvent{type: type} = event) when is_struct(event),
    do: type |> String.split("/") |> event_context_and_class()

  defp event_context_and_class(["archidep", "accounts", _action]),
    do: [context: "accounts", class: "badge badge-primary"]

  defp event_context_and_class(["archidep", context, _action]),
    do: [context: context, class: "badge badge-accent"]

  defp event_context_and_class(parts), do: [context: Enum.join(parts, "/"), class: "badge"]

  @spec event_action(map) :: Phoenix.LiveView.Rendered.t()

  attr(:event, StoredEvent, required: true)

  def event_action(assigns) when is_map(assigns) do
    assigns = assign(assigns, event_action_and_class(assigns.event))

    ~H"""
    <div class={@class}>{@action}</div>
    """
  end

  defp event_action_and_class(%StoredEvent{type: type} = event) when is_struct(event),
    do: type |> String.split("/") |> event_action_and_class()

  defp event_action_and_class(["archidep", "accounts", action])
       when action in ["admin-user-created", "user-password-changed"],
       do: [action: action, class: "badge badge-error"]

  defp event_action_and_class(["archidep", "accounts", action]),
    do: [action: action, class: "badge badge-warning"]

  defp event_action_and_class(["archidep", _context, action]),
    do: [action: action, class: "badge badge-info"]

  defp event_action_and_class(parts), do: [action: Enum.join(parts, "/"), class: "badge"]

  @spec event_entity(map) :: Phoenix.LiveView.Rendered.t()

  attr(:event, StoredEvent, required: true)

  def event_entity(assigns) when is_map(assigns) do
    case assigns.event.entity do
      %UserAccount{username: username} ->
        assigns = assign(assigns, :username, username)

        ~H"""
        <span class="flex items-center">
          <Heroicons.user solid class="w-6 h-6 mr-1" />
          {@username}
        </span>
        """

      _anything_else ->
        ~H"""
        <Heroicons.question_mark_circle solid class="w-6 h-6 me-1" /> unknown
        """
    end
  end
end
