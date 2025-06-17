defmodule ArchiDepWeb.Servers.ServerComponents do
  use Phoenix.Component

  import ArchiDep.Servers.ServerConnectionState
  import ArchiDepWeb.Helpers.AuthHelpers
  alias ArchiDep.Authentication
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

  attr :auth, Authentication, doc: "the authentication context"
  attr :server, Server, doc: "the server to display"
  attr :state, ServerRealTimeState, doc: "the current state of the server", default: nil

  def server_card(assigns) do
    {card_class, badge_class, badge_text, status_text} =
      case assigns.state do
        nil ->
          {"bg-neutral text-neutral-content", "badge-info", "Not connected",
           "No connection to this server."}

        %ServerRealTimeState{connection_state: connecting_state()} ->
          {"bg-info text-info-content animate-pulse", "badge-primary", "Connecting",
           "Connecting to the server..."}

        %ServerRealTimeState{
          connection_state:
            retry_connecting_state(retrying: %{retry: retry, time: time, in_seconds: in_seconds})
        } ->
          {"bg-info text-info-content", "badge-primary", "Reconnecting",
           retry_connecting(%{
             auth: assigns.auth,
             server: assigns.server,
             retry: retry,
             time: time,
             in_seconds: in_seconds
           })}

        %ServerRealTimeState{connection_state: connected_state()} ->
          {"bg-success text-success-content", "badge-success", "Connected",
           "Connected to the server."}

        %ServerRealTimeState{connection_state: reconnecting_state()} ->
          {"bg-info text-info-content animate-pulse", "badge-primary", "Reconnecting",
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
        <div class="card-title flex flex-wrap justify-between text-xs sm:text-sm md:text-base">
          <h2 class="flex items-center gap-x-2">
            <Heroicons.server solid class="size-4 sm:size-5 md:size-6" />
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
            <.server_problem auth={@auth} problem={problem} />
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :auth, Authentication, doc: "the authentication context"
  attr :problem, :any, doc: "the problem to display"

  def server_problem(%{problem: {:server_authentication_failed, :username, username}} = assigns) do
    assigns = assign(assigns, :username, username)

    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <span>Authentication failed for user <code>{@username}</code></span>
    </div>
    """
  end

  def server_problem(
        %{problem: {:server_authentication_failed, :app_username, username}} = assigns
      ) do
    assigns = assign(assigns, :username, username)

    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <span>
        <%= if has_role?(@auth, :root) do %>
          Authentication failed for application user <code>{@username}</code>
        <% else %>
          Authentication failed
        <% end %>
      </span>
    </div>
    """
  end

  def server_problem(assigns) do
    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <span>Oops, a problem occurred.</span>
    </div>
    """
  end

  defp retry_connecting(assigns) do
    id = "server-#{assigns.server.id}-retry-connecting"

    end_time = DateTime.add(assigns.time, assigns.in_seconds, :second)

    remaining_seconds =
      max(
        0,
        DateTime.diff(
          end_time,
          DateTime.utc_now(),
          :second
        )
      )

    assigns =
      assigns
      |> Map.put(:id, id)
      |> Map.put(:end_time, end_time)
      |> Map.put(:remaining_seconds, remaining_seconds)

    ~H"""
    Will retry connecting
    <span id={@id} data-end-time={DateTime.to_iso8601(@end_time)} phx-hook="remainingSeconds">
      in {@remaining_seconds}s
    </span>
    <%= if has_role?(@auth, :root) do %>
      (attempt #{@retry + 1})
    <% end %>...
    """
  end
end
