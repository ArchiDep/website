defmodule ArchiDepWeb.Servers.ServerHelpComponent do
  @moduledoc """
  A component that provides help and troubleshooting tips for servers,
  displaying common issues and solutions related to server setup and connection
  problems.
  """

  use ArchiDepWeb, :component

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState

  attr :auth, Authentication, doc: "the authentication context", required: true
  attr :server, Server, doc: "the server for which help is provided", required: true
  attr :state, ServerRealTimeState, doc: "the current state of the server", default: nil

  @spec server_help(map()) :: Rendered.t()
  def server_help(assigns) do
    ~H"""
    <!-- Inactive server -->
    <.troubleshooting_note :if={@server.set_up_at == nil and not @server.active}>
      <p>
        <strong>Oops.</strong> It appears that you have mistakenly created your
        server in an inactive state. We will only connect to servers that are
        marked as active.
      </p>
    </.troubleshooting_note>
    <!-- Connection timeout -->
    <.troubleshooting_note :if={
      @server.set_up_at == nil and @server.active and @state != nil and
        (connecting?(@state.connection_state) or retry_connecting?(@state.connection_state)) and
        problem?(@state, :server_connection_timed_out)
    }>
      <p>
        <strong>Oops.</strong> We can't seem to connect to your server. This
        could be due to a misconfiguration or an issue with the server itself.
        Please check the following:
      </p>
      <ul class="mt-2 list-disc list-outside pl-6 flex flex-col gap-y-2">
        <li>Is your server running? We can't connect to it if it's off.</li>
        <li>Did you configure the correct IP address?</li>
        <li>
          We are attempting to open an SSH connection to port {@server.ssh_port ||
            22}. Is this port open in your cloud provider's firewall?
        </li>
        <li>
          <a href="https://youtu.be/5UT8RkSmN4k?feature=shared" target="_blank" class="no-hover">
            Have you tried turning it off and on again?
          </a>
        </li>
      </ul>
    </.troubleshooting_note>
    <!-- Connection refused -->
    <.troubleshooting_note :if={
      @server.set_up_at == nil and @server.active and @state != nil and
        (connecting?(@state.connection_state) or retry_connecting?(@state.connection_state)) and
        problem?(@state, :server_connection_refused)
    }>
      <p>
        <strong>Oops.</strong> We've reached a server at the IP address you
        provided, but it's refusing to let us open a connection.
      </p>
      <ul class="mt-2 list-disc list-outside pl-6 flex flex-col gap-y-2">
        <li>
          Did you configure the correct IP address? We might be trying to reach
          the wrong server.
        </li>
        <li>
          Is your server rebooting? It might not be ready to accept connections
          yet. Please wait a minute and try again.
        </li>
      </ul>
    </.troubleshooting_note>
    <!-- Authentication failure -->
    <.troubleshooting_note :if={
      @server.set_up_at == nil and @server.active and @state != nil and
        connection_failed?(@state.connection_state) and
        problem?(@state, :server_authentication_failed)
    }>
      <p>
        <strong>Oops.</strong> We've reached an SSH server at the IP address and
        port you provided, but it's not letting us in with the provided
        username.
      </p>
      <ul class="mt-2 list-disc list-outside pl-6 flex flex-col gap-y-2">
        <li>
          Did you configure the correct username? We might be trying to log in
          with the wrong user.
        </li>
        <li>
          Did you add the course's SSH public key to the user's authorized keys?
          We won't be able to log in without it.
        </li>
      </ul>
    </.troubleshooting_note>
    <!-- Open port check failed -->
    <.troubleshooting_note :if={
      @server.active and @state != nil and
        connected?(@state.connection_state) and
        problem?(@state, :server_open_ports_check_failed)
    }>
      <p>
        <strong>Oops.</strong> We've connected to your server but we can't seem
        to reach some of the ports that should be open.  Are you sure you opened
        the required ports in your cloud provider's firewall?
      </p>
    </.troubleshooting_note>
    <div
      :if={
        @server.set_up_at != nil and @state != nil and connected?(@state.connection_state) and
          not problems?(@state) and not busy?(@state)
      }
      class="alert alert-success alert-soft"
    >
      <Heroicons.check_circle class="size-4" />
      <span>
        <strong>Congratulations!</strong> You've successfully registered your
        server and are ready to go. You can now use SSH to connect to it.
      </span>
    </div>
    """
  end

  defp busy?(%ServerRealTimeState{current_job: nil}), do: false
  defp busy?(%ServerRealTimeState{}), do: true

  defp problems?(%ServerRealTimeState{problems: []}), do: false
  defp problems?(%ServerRealTimeState{}), do: true

  defp problem?(%ServerRealTimeState{problems: problems}, type),
    do: Enum.any?(problems, fn problem -> elem(problem, 0) == type end)
end
