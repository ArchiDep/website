defmodule ArchiDepWeb.Servers.ServerRetryHandlersTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Servers
  alias ArchiDep.Support.Factory
  alias ArchiDepWeb.Servers.ServerRetryHandlers
  alias Phoenix.LiveView.Socket

  setup :verify_on_exit!

  describe "handle_retry_connecting_event/2" do
    test "retry connecting to the server" do
      auth = Factory.build(:authentication)
      server_id = UUID.generate()
      socket = socket_with_auth(auth)

      expect(Servers.ContextMock, :retry_connecting, 1, fn ^auth, ^server_id -> :ok end)

      assert {:noreply, returned} =
               ServerRetryHandlers.handle_retry_connecting_event(socket, server_id)

      assert socket_state(returned) == socket_state(socket)
    end

    test "notify when the server no longer exists" do
      auth = Factory.build(:authentication)
      server_id = UUID.generate()
      socket = socket_with_auth(auth)

      expect(Servers.ContextMock, :retry_connecting, 1, fn ^auth, ^server_id ->
        {:error, :server_not_found}
      end)

      assert {:noreply, returned} =
               ServerRetryHandlers.handle_retry_connecting_event(socket, server_id)

      assert socket_state(returned) == %{
               socket_state(socket)
               | notifications: [
                   {:error, gettext("Cannot retry because the server no longer exists.")}
                 ]
             }
    end
  end

  describe "handle_retry_ansible_playbook_event/3" do
    test "retry running the playbook" do
      auth = Factory.build(:authentication)
      server_id = UUID.generate()
      playbook = "setup"
      socket = socket_with_auth(auth)

      expect(Servers.ContextMock, :retry_ansible_playbook, 1, fn ^auth, ^server_id, ^playbook ->
        :ok
      end)

      assert {:noreply, returned} =
               ServerRetryHandlers.handle_retry_ansible_playbook_event(
                 socket,
                 server_id,
                 playbook
               )

      assert socket_state(returned) == socket_state(socket)
    end

    test "notify when the server is not connected" do
      auth = Factory.build(:authentication)
      server_id = UUID.generate()
      playbook = "setup"
      socket = socket_with_auth(auth)

      expect(Servers.ContextMock, :retry_ansible_playbook, 1, fn ^auth, ^server_id, ^playbook ->
        {:error, :server_not_connected}
      end)

      assert {:noreply, returned} =
               ServerRetryHandlers.handle_retry_ansible_playbook_event(
                 socket,
                 server_id,
                 playbook
               )

      assert socket_state(returned) == %{
               socket_state(socket)
               | notifications: [
                   {:error, gettext("Cannot retry because the server is not connected.")}
                 ]
             }
    end

    test "notify when the server is busy" do
      auth = Factory.build(:authentication)
      server_id = UUID.generate()
      playbook = "setup"
      socket = socket_with_auth(auth)

      expect(Servers.ContextMock, :retry_ansible_playbook, 1, fn ^auth, ^server_id, ^playbook ->
        {:error, :server_busy}
      end)

      assert {:noreply, returned} =
               ServerRetryHandlers.handle_retry_ansible_playbook_event(
                 socket,
                 server_id,
                 playbook
               )

      assert socket_state(returned) == %{
               socket_state(socket)
               | notifications: [
                   {:error,
                    gettext("Cannot retry because the server is busy. Please try again later.")}
                 ]
             }
    end

    test "notify when the server no longer exists" do
      auth = Factory.build(:authentication)
      server_id = UUID.generate()
      playbook = "setup"
      socket = socket_with_auth(auth)

      expect(Servers.ContextMock, :retry_ansible_playbook, 1, fn ^auth, ^server_id, ^playbook ->
        {:error, :server_not_found}
      end)

      assert {:noreply, returned} =
               ServerRetryHandlers.handle_retry_ansible_playbook_event(
                 socket,
                 server_id,
                 playbook
               )

      assert socket_state(returned) == %{
               socket_state(socket)
               | notifications: [
                   {:error, gettext("Cannot retry because the server no longer exists.")}
                 ]
             }
    end
  end

  describe "handle_retry_checking_open_ports_event/2" do
    test "retry checking the open ports" do
      auth = Factory.build(:authentication)
      server_id = UUID.generate()
      socket = socket_with_auth(auth)

      expect(Servers.ContextMock, :retry_checking_open_ports, 1, fn ^auth, ^server_id -> :ok end)

      assert {:noreply, returned} =
               ServerRetryHandlers.handle_retry_checking_open_ports_event(socket, server_id)

      assert socket_state(returned) == socket_state(socket)
    end

    test "notify when the server is not connected" do
      auth = Factory.build(:authentication)
      server_id = UUID.generate()
      socket = socket_with_auth(auth)

      expect(Servers.ContextMock, :retry_checking_open_ports, 1, fn ^auth, ^server_id ->
        {:error, :server_not_connected}
      end)

      assert {:noreply, returned} =
               ServerRetryHandlers.handle_retry_checking_open_ports_event(socket, server_id)

      assert socket_state(returned) == %{
               socket_state(socket)
               | notifications: [
                   {:error, gettext("Cannot retry because the server is not connected.")}
                 ]
             }
    end

    test "notify when the server is busy" do
      auth = Factory.build(:authentication)
      server_id = UUID.generate()
      socket = socket_with_auth(auth)

      expect(Servers.ContextMock, :retry_checking_open_ports, 1, fn ^auth, ^server_id ->
        {:error, :server_busy}
      end)

      assert {:noreply, returned} =
               ServerRetryHandlers.handle_retry_checking_open_ports_event(socket, server_id)

      assert socket_state(returned) == %{
               socket_state(socket)
               | notifications: [
                   {:error,
                    gettext("Cannot retry because the server is busy. Please try again later.")}
                 ]
             }
    end

    test "notify when the server no longer exists" do
      auth = Factory.build(:authentication)
      server_id = UUID.generate()
      socket = socket_with_auth(auth)

      expect(Servers.ContextMock, :retry_checking_open_ports, 1, fn ^auth, ^server_id ->
        {:error, :server_not_found}
      end)

      assert {:noreply, returned} =
               ServerRetryHandlers.handle_retry_checking_open_ports_event(socket, server_id)

      assert socket_state(returned) == %{
               socket_state(socket)
               | notifications: [
                   {:error, gettext("Cannot retry because the server no longer exists.")}
                 ]
             }
    end
  end

  # The retry handlers either leave the socket untouched or add a single flash
  # notification. Putting a flash spreads bookkeeping across assigns.flash, the
  # assigns change-tracking marker and private.live_temp[:flash]; projecting the
  # socket with all three normalized lets a test assert by equality that nothing
  # else changed — a stray assign, redirect (socket.redirected) or pushed event
  # (private.live_temp[:push_events]) still surfaces — while the flash itself is
  # pinned through the notifications projection (a Flashy notification holds a
  # render function and cannot be compared as a whole value).
  defp socket_state(%Socket{assigns: assigns, private: private} = socket),
    do: %{
      socket: %{
        socket
        | assigns: Map.drop(assigns, [:flash, :__changed__]),
          private: %{private | live_temp: Map.delete(private.live_temp, :flash)}
      },
      notifications: flash_notifications(assigns)
    }

  defp socket_with_auth(auth),
    do: %Socket{assigns: %{__changed__: %{}, flash: %{}, auth: auth}}
end
