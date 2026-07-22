defmodule ArchiDepWeb.LiveRefreshHost do
  @moduledoc false

  # Minimal host live view exercising `ArchiDepWeb.LiveRefresh`: it tracks a
  # single assign, a list assign, and a pair of single assigns fed by one hook
  # (`attach_all`) with toy refreshers, and records any message that falls
  # through the hooks into `:fell_through` so a test can prove the `:cont` path
  # reached the live view's own `handle_info/2`.

  use Phoenix.LiveView

  alias ArchiDepWeb.LiveRefresh

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket
    |> assign(single: 0, list: [{:a, 1}, {:b, 2}, {:c, 3}], one: 0, two: 0, fell_through: nil)
    |> LiveRefresh.attach(:single, &refresh_single/2)
    |> LiveRefresh.attach_collection(:list, &refresh_element/2)
    |> LiveRefresh.attach_all([{:one, &refresh_one/2}, {:two, &refresh_two/2}])
    |> then(&{:ok, &1})
  end

  @impl Phoenix.LiveView
  def render(assigns), do: ~H"<div></div>"

  @impl Phoenix.LiveView
  def handle_info(msg, socket), do: {:noreply, assign(socket, :fell_through, msg)}

  defp refresh_single(_current, {:set_single, value}), do: {:ok, value}
  defp refresh_single(_current, _msg), do: :ignore

  defp refresh_element({id, _value}, {:set, id, value}), do: {:ok, {id, value}}
  defp refresh_element(_element, _msg), do: :ignore

  defp refresh_one(_current, {:set_both, value}), do: {:ok, value}
  defp refresh_one(_current, {:set_one, value}), do: {:ok, value}
  defp refresh_one(_current, _msg), do: :ignore

  defp refresh_two(_current, {:set_both, value}), do: {:ok, value}
  defp refresh_two(_current, _msg), do: :ignore
end

defmodule ArchiDepWeb.LiveRefreshTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  alias ArchiDepWeb.LiveRefreshHost

  @initial_list [{:a, 1}, {:b, 2}, {:c, 3}]

  describe "attach/3" do
    test "swaps the tracked assign when the refresher claims the message", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, LiveRefreshHost)

      send(view.pid, {:set_single, 42})
      wait_for_socket_assigns!(view, &(&1.single == 42), "single swapped")

      assert state(view) == {42, @initial_list, 0, 0, nil}
    end
  end

  describe "attach_collection/3" do
    test "replaces the claimed element in place and preserves order", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, LiveRefreshHost)

      send(view.pid, {:set, :b, 99})

      wait_for_socket_assigns!(
        view,
        &(&1.list == [{:a, 1}, {:b, 99}, {:c, 3}]),
        "element swapped"
      )

      assert state(view) == {0, [{:a, 1}, {:b, 99}, {:c, 3}], 0, 0, nil}
    end

    test "passes a message matching no element through untouched", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, LiveRefreshHost)

      send(view.pid, {:set, :missing, 99})
      wait_for_socket_assigns!(view, &(&1.fell_through == {:set, :missing, 99}), "fell through")

      assert state(view) == {0, @initial_list, 0, 0, {:set, :missing, 99}}
    end
  end

  describe "attach_all/2" do
    test "updates every assign a single message claims", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, LiveRefreshHost)

      send(view.pid, {:set_both, 5})
      wait_for_socket_assigns!(view, &(&1.one == 5 and &1.two == 5), "both swapped")

      assert state(view) == {0, @initial_list, 5, 5, nil}
    end

    test "halts a message even when only one assign claims it", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, LiveRefreshHost)

      send(view.pid, {:set_one, 9})
      wait_for_socket_assigns!(view, &(&1.one == 9), "one swapped")

      # `two` is untouched and the message halted, so it never reached the live
      # view's own `handle_info/2` (fall-through stays nil).
      assert state(view) == {0, @initial_list, 9, 0, nil}
    end
  end

  describe "hook composition" do
    test "an unclaimed message reaches the live view's own handle_info", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, LiveRefreshHost)

      send(view.pid, {:host_only, :payload})
      wait_for_socket_assigns!(view, &(&1.fell_through == {:host_only, :payload}), "fell through")

      assert state(view) == {0, @initial_list, 0, 0, {:host_only, :payload}}
    end

    test "a message claimed by one hook leaves the other tracked assign untouched", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, LiveRefreshHost)

      send(view.pid, {:set_single, 7})
      wait_for_socket_assigns!(view, &(&1.single == 7), "single swapped")

      # The collection assign, the `attach_all` pair and the fall-through record
      # are all untouched.
      assert state(view) == {7, @initial_list, 0, 0, nil}
    end
  end

  # Projects the host live view's socket assigns to the whole tuple the tests
  # assert by equality.
  defp state(view) do
    assigns = :sys.get_state(view.pid).socket.assigns
    {assigns.single, assigns.list, assigns.one, assigns.two, assigns.fell_through}
  end
end
