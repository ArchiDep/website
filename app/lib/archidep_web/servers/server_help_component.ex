defmodule ArchiDepWeb.Servers.ServerHelpComponent do
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
    <.troubleshooting_note :if={@server.set_up_at == nil and not @server.active}>
      <p>
        <strong>Oops.</strong> It appears that you have mistakenly created your
        server in an inactive state. We will only connect to servers that are
        marked as active.
      </p>
    </.troubleshooting_note>
    <.troubleshooting_note :if={
      @server.set_up_at == nil and @server.active and @state != nil and
        (connecting?(@state.connection_state) or retry_connecting?(@state.connection_state))
    }>
      <p>
        <strong>Oops.</strong> We can't seem to connect to your server. This
        could be due to a misconfiguration or an issue with the server itself.
        Please check the following:
      </p>
      <ul class="mt-2 list-disc list-outside pl-6 flex flex-col gap-y-2">
        <li>Is your server running? We can't connect to it if it's off.</li>
        <li>Did you configure the correct username & IP address?</li>
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
    """
  end
end
