defmodule ArchiDepWeb.LiveRefresh do
  @moduledoc """
  Keeps a cached read-model current from PubSub without coupling the use point
  to specific events.

  A live view subscribes through `Context.subscribe_<entity>/1` and attaches a
  hook that forwards each `:handle_info` message to
  `Context.refresh_<entity>/2`, which owns the mapping from a broadcast message
  to the read-model update. The contexts' real-time messages stay the shared
  contract; this helper spares each consumer from re-implementing the "match the
  relevant events, apply the merge, fall back to a refetch" plumbing and from
  naming those events at the use point.

  A refresher answers `{:ok, updated}` for a message that concerns the tracked
  value or `:ignore` for any other message. The hook halts a claimed message
  (swapping the assign) and lets everything else fall through to the live view's
  own `handle_info/2` clauses.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]
  alias Phoenix.LiveView.Socket

  @typedoc """
  Reconciles the current value from a message, or declines a message that does
  not concern it.
  """
  @type refresher(value) :: (value | nil, term() -> {:ok, value} | :ignore)

  @doc """
  Tracks the single assign named `key`. On each info message the hook asks
  `refresher` to reconcile `socket.assigns[key]`: `{:ok, updated}` swaps the
  assign and halts the message, `:ignore` passes it through untouched.
  """
  @spec attach(Socket.t(), atom(), refresher(value)) :: Socket.t() when value: term()
  def attach(socket, key, refresher) do
    attach_hook(socket, {:refresh, key}, :handle_info, fn msg, socket ->
      case refresher.(socket.assigns[key], msg) do
        {:ok, updated} -> {:halt, assign(socket, key, updated)}
        :ignore -> {:cont, socket}
      end
    end)
  end

  @doc """
  Tracks one element of the list assign named `key`. The hook applies the
  single-entity `refresher` to each element until one answers `{:ok, updated}`;
  that element is replaced in place (order preserved) and the message is halted.
  If no element claims the message, it passes through untouched. The element's
  own id guard inside `refresher` is what selects the target, so the web layer
  still names nothing.
  """
  @spec attach_collection(Socket.t(), atom(), refresher(element)) :: Socket.t()
        when element: term()
  def attach_collection(socket, key, refresher) do
    attach_hook(socket, {:refresh, key}, :handle_info, fn msg, socket ->
      case replace_claimed(socket.assigns[key], msg, refresher, []) do
        {:updated, list} -> {:halt, assign(socket, key, list)}
        :unclaimed -> {:cont, socket}
      end
    end)
  end

  defp replace_claimed([], _msg, _refresher, _seen), do: :unclaimed

  defp replace_claimed([element | rest], msg, refresher, seen) do
    case refresher.(element, msg) do
      {:ok, updated} -> {:updated, Enum.reverse(seen, [updated | rest])}
      :ignore -> replace_claimed(rest, msg, refresher, [element | seen])
    end
  end
end
