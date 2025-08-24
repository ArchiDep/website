defmodule ArchiDepWeb.Servers.ServerRetryHandlers do
  @moduledoc """
  Common handlers to retry failed server-related operations in live views.
  """

  use Gettext, backend: ArchiDepWeb.Gettext

  import ArchiDep.Helpers.PipeHelpers
  import Flashy
  alias ArchiDep.Servers
  alias ArchiDepWeb.Components.Notifications.Message
  alias Ecto.UUID
  alias Phoenix.LiveView.Socket

  @spec handle_retry_connecting_event(Socket.t(), UUID.t()) :: {:noreply, Socket.t()}
  def handle_retry_connecting_event(
        %Socket{assigns: %{auth: auth}} = socket,
        server_id
      ) do
    :ok = Servers.retry_connecting(auth, server_id)
    noreply(socket)
  end

  @spec handle_retry_ansible_playbook_event(
          Socket.t(),
          UUID.t(),
          String.t()
        ) :: {:noreply, Socket.t()}
  def handle_retry_ansible_playbook_event(
        %Socket{assigns: %{auth: auth}} = socket,
        server_id,
        playbook
      )
      when is_binary(playbook) do
    case Servers.retry_ansible_playbook(auth, server_id, playbook) do
      :ok ->
        noreply(socket)

      {:error, :server_not_connected} ->
        server_not_connected(socket)

      {:error, :server_busy} ->
        server_is_busy(socket)
    end
  end

  @spec handle_retry_checking_open_ports_event(Socket.t(), UUID.t()) :: {:noreply, Socket.t()}
  def handle_retry_checking_open_ports_event(
        %Socket{assigns: %{auth: auth}} = socket,
        server_id
      ) do
    case Servers.retry_checking_open_ports(auth, server_id) do
      :ok ->
        noreply(socket)

      {:error, :server_not_connected} ->
        server_not_connected(socket)

      {:error, :server_busy} ->
        server_is_busy(socket)
    end
  end

  defp server_not_connected(socket),
    do:
      socket
      |> put_notification(
        Message.new(
          :error,
          gettext("Cannot retry because the server is not connected.")
        )
      )
      |> noreply()

  defp server_is_busy(socket),
    do:
      socket
      |> put_notification(
        Message.new(
          :error,
          gettext("Cannot retry because the server is busy. Please try again later.")
        )
      )
      |> noreply()
end
