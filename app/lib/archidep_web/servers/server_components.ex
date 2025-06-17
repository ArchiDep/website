defmodule ArchiDepWeb.Servers.ServerComponents do
  use Phoenix.Component

  import ArchiDep.Servers.ServerConnectionState
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState

  attr :server, Server, doc: "the server whose name to display"

  def server_name(assigns) do
    ~H"""
    <%= if @server.name do %>
      {@server.name}
    <% else %>
      <span class="font-mono">
        {Server.default_name(@server)}
      </span>
    <% end %>
    """
  end

  attr :server, Server, doc: "the server to display"
  attr :state, ServerRealTimeState, doc: "the current state of the server", default: nil

  def server_card(assigns) do
    {card_class, badge_class, badge_text, status_text} =
      case assigns.state do
        nil ->
          {"bg-neutral text-neutral-content", "badge-info", "Not connected",
           "No connection to this server."}

        %ServerRealTimeState{connection_state: connecting_state()} ->
          {"bg-info text-info-content", "badge-primary", "Connecting",
           "Connecting to the server..."}

        %ServerRealTimeState{connection_state: retry_connecting_state()} ->
          {"bg-info text-info-content", "badge-primary", "Reconnecting",
           "Will retry connecting soon..."}

        %ServerRealTimeState{connection_state: connected_state()} ->
          {"bg-success text-success-content", "badge-success", "Connected",
           "Connected to the server."}

        %ServerRealTimeState{connection_state: reconnecting_state()} ->
          {"bg-info text-info-content", "badge-primary", "Reconnecting",
           "Reconnecting to the server..."}

        %ServerRealTimeState{connection_state: connection_failed_state()} ->
          {"bg-error text-error-content", "badge-error", "Connection failed",
           "Could not connect to the server."}

        %ServerRealTimeState{connection_state: disconnected_state()} ->
          {"bg-info text-info-content", "badge-primary", "Disconnected",
           "The connection to the server was lost."}
      end

    assigns =
      assigns
      |> assign(:card_class, card_class)
      |> assign(:badge_class, badge_class)
      |> assign(:badge_text, badge_text)
      |> assign(:status_text, status_text)

    ~H"""
    <div class={["card", @card_class]}>
      <div class="card-body">
        <div class="card-title flex justify-between">
          <h2 class="flex items-center gap-x-2">
            <Heroicons.server solid class="size-6" />
            <.server_name server={@server} />
          </h2>
          <div class={["badge badge-soft", @badge_class]}>
            {@badge_text}
          </div>
        </div>
        <p>
          {@status_text}
        </p>
        <ul>
          <li :for={problem <- @state.problems}>
            <.server_problem problem={problem} />
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :problem, :any, doc: "the problem to display"

  def server_problem(assigns) do
    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <span>Error! Task failed successfully.</span>
    </div>
    """
  end
end
