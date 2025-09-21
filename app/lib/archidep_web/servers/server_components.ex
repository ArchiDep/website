defmodule ArchiDepWeb.Servers.ServerComponents do
  @moduledoc false

  use ArchiDepWeb, :component

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDepWeb.Helpers.AuthHelpers
  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.SSHKeyFingerprint
  alias Phoenix.LiveView.JS

  attr :server, Server, doc: "the server whose name to display"

  @spec server_name(map()) :: Rendered.t()
  def server_name(assigns) do
    ~H"""
    <%= if @server.name do %>
      {@server.name}
    <% else %>
      <span class="font-mono">
        {Server.ssh_connection_description(@server)}
      </span>
    <% end %>
    """
  end

  attr :auth, Authentication, doc: "the authentication context"
  attr :server, Server, doc: "the server to display"
  attr :state, ServerRealTimeState, doc: "the current state of the server", default: nil
  attr :class, :string, doc: "extra CSS classes to apply to the card", default: nil
  attr :details_link, :string, doc: "the link to the server's details page", default: nil
  attr :edit_enabled, :boolean, doc: "whether editing the server is enabled", default: false

  attr :on_edit, JS, doc: "JS command to execute when editing the server", default: nil

  attr :on_retry_connection, JS,
    doc: "JS command to execute when retrying the connection",
    default: nil

  attr :on_retry_operation, JS,
    doc: "function to call when retrying an operation",
    default: nil

  @spec server_card(map()) :: Rendered.t()
  def server_card(assigns) do
    server = assigns.server
    state = assigns.state

    {badge_class, badge_text} = server_card_badge(server, state && state.connection_state)

    body =
      server_card_body(
        state && state.connection_state,
        state && state.current_job,
        assigns.auth,
        assigns.server
      )

    retry_text = server_card_retry_text(state && state.connection_state)

    filtered_problems = filter_problems(state)
    card_class = server_card_class(state && state.connection_state, filtered_problems)

    assigns =
      assigns
      |> assign(:card_classes, [card_class, assigns.class])
      |> assign(:badge_class, badge_class)
      |> assign(:badge_text, badge_text)
      |> assign(:body, body)
      |> assign(:retry_text, retry_text)
      |> assign(:connected, state != nil and connected?(state.connection_state))
      |> assign(:connecting_or_reconnecting, server_connecting_or_reconnecting?(state))
      |> assign(:busy, state != nil and state.current_job != nil)

    ~H"""
    <div class={["card"] ++ @card_classes}>
      <div class="card-body">
        <div class="card-title flex flex-wrap justify-between text-xs sm:text-sm md:text-base">
          <div class="flex items-center gap-x-2">
            <Heroicons.server solid class="size-4 sm:size-5 md:size-6" />
            <.server_name server={@server} />
          </div>
          <div class={["badge badge-soft", @badge_class]}>
            {@badge_text}
          </div>
        </div>
        <div class="flex items-center gap-x-2">
          <Heroicons.bolt :if={!@busy and (@connected or @connecting_or_reconnecting)} class="size-4" />
          <Heroicons.bolt_slash
            :if={!@busy and !@connected and !@connecting_or_reconnecting}
            class="size-4"
          />
          <Heroicons.arrow_path :if={@busy} class="size-4 animate-spin" />
          <span>{@body}</span>
        </div>
        <ul :if={@state} class="flex flex-col gap-2">
          <li :for={problem <- @state.problems}>
            <.server_problem
              auth={@auth}
              problem={problem}
              connected={@connected}
              current_job={@state.current_job}
              on_retry_operation={@on_retry_operation}
            />
          </li>
        </ul>
        <div
          :if={
            (@retry_text != nil and @on_retry_connection != nil) or
              (@edit_enabled and @on_edit != nil) or @details_link != nil
          }
          class="card-actions justify-end"
        >
          <button
            :if={@retry_text != nil and @on_retry_connection != nil}
            type="button"
            class="btn btn-sm btn-secondary"
            phx-click={@on_retry_connection}
          >
            <span class="flex items-center gap-x-2">
              <Heroicons.arrow_path class="size-4" />
              {@retry_text}
            </span>
          </button>
          <button
            :if={@edit_enabled and @on_edit != nil}
            type="button"
            class="btn btn-sm btn-primary"
            phx-disabled={@connecting_or_reconnecting or @busy}
            phx-click={@on_edit}
          >
            <span class="flex items-center gap-x-2">
              <Heroicons.pencil class="size-4" />
              <span>{gettext("Edit")}</span>
            </span>
          </button>
          <.link :if={@details_link} class="btn btn-sm btn-info" navigate={@details_link}>
            <span class="flex items-center gap-x-2">
              <Heroicons.eye class="size-4" />
              <span>{gettext("Details")}</span>
            </span>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  attr :auth, Authentication, doc: "the authentication context"
  attr :server, Server, doc: "the server to display"
  attr :state, ServerRealTimeState, doc: "the current state of the server", default: nil
  attr :class, :string, doc: "extra CSS classes to apply to the card", default: nil
  attr :details_link, :string, doc: "the link to the server's details page", default: nil

  @spec admin_server_card(map()) :: Rendered.t()
  def admin_server_card(assigns) do
    server = assigns.server
    state = assigns.state

    body =
      server_card_body(
        state && state.connection_state,
        state && state.current_job,
        assigns.auth,
        server
      )

    short_status =
      server_card_short_status(
        state && state.connection_state,
        state && state.current_job,
        assigns.auth,
        server
      )

    filtered_problems = filter_problems(state)
    card_class = server_card_class(state && state.connection_state, filtered_problems)

    assigns =
      assigns
      |> assign(:card_classes, [card_class, assigns.class])
      |> assign(:body, body)
      |> assign(:short_status, short_status)
      |> assign(:connected, state != nil and connected?(state.connection_state))
      |> assign(:connecting_or_reconnecting, server_connecting_or_reconnecting?(state))
      |> assign(:busy, state != nil and state.current_job != nil)

    ~H"""
    <div class={["card card-xs"] ++ @card_classes} phx-click={JS.navigate(@details_link)}>
      <div class="card-body">
        <div class="card-title flex flex-wrap justify-between">
          <div class="flex items-center gap-x-2">
            <Heroicons.server solid class="size-4" />
            <span class="tooltip">
              <div class="tooltip-content font-mono">
                {Server.ssh_connection_description(@server)}
              </div>
              {server_owner_name(@server)}
            </span>
          </div>
          <div class="tooltip flex items-center gap-2 font-normal">
            {@short_status}
            <Heroicons.bolt
              :if={!@busy and (@connected or @connecting_or_reconnecting)}
              class="size-4"
            />
            <Heroicons.bolt_slash
              :if={!@busy and !@connected and !@connecting_or_reconnecting}
              class="size-4"
            />
            <Heroicons.arrow_path :if={@busy} class="size-4 animate-spin" />
            <div class="tooltip-content">{@body}</div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp filter_problems(nil), do: []
  defp filter_problems(%ServerRealTimeState{set_up_at: nil, problems: problems}), do: problems
  # Ignore connection timeout problems after the server has been set up. The
  # server might simply be offline.
  defp filter_problems(%ServerRealTimeState{problems: problems}),
    do:
      Enum.reject(
        problems,
        &match?({:server_connection_timed_out, _host, _port, _username}, &1)
      )

  defp server_card_class(nil, _problems), do: "bg-neutral text-neutral-content"
  defp server_card_class(not_connected_state(), _problems), do: "bg-neutral text-neutral-content"
  defp server_card_class(connecting_state(), []), do: "bg-info text-info-content animate-pulse"

  defp server_card_class(connecting_state(), _problems),
    do: "bg-warning text-warning-content animate-pulse"

  defp server_card_class(retry_connecting_state(), []), do: "bg-info text-info-content"

  defp server_card_class(retry_connecting_state(), _problems),
    do: "bg-warning text-warning-content"

  defp server_card_class(connected_state(), []), do: "bg-success text-success-content"
  defp server_card_class(connected_state(), _problems), do: "bg-warning text-warning-content"
  defp server_card_class(reconnecting_state(), []), do: "bg-info text-info-content animate-pulse"

  defp server_card_class(reconnecting_state(), _problems),
    do: "bg-warning text-warning-content animate-pulse"

  defp server_card_class(connection_failed_state(), _problems), do: "bg-error text-error-content"
  defp server_card_class(disconnected_state(), []), do: "bg-info text-info-content"
  defp server_card_class(disconnected_state(), _problems), do: "bg-warning text-warning-content"

  defp server_card_badge(%Server{active: false}, _state), do: {"badge-info", gettext("Inactive")}
  defp server_card_badge(_server, nil), do: {"badge-info", gettext("Not connected")}

  defp server_card_badge(_server, not_connected_state()),
    do: {"badge-info", gettext("Not connected")}

  defp server_card_badge(_server, connecting_state()),
    do: {"badge-primary", gettext("Connecting")}

  defp server_card_badge(_server, retry_connecting_state()),
    do: {"badge-primary", gettext("Reconnecting")}

  defp server_card_badge(_server, connected_state()), do: {"badge-success", gettext("Connected")}

  defp server_card_badge(_server, reconnecting_state()),
    do: {"badge-primary", gettext("Reconnecting")}

  defp server_card_badge(_server, connection_failed_state()),
    do: {"badge-error", gettext("Connection failed")}

  defp server_card_badge(_server, disconnected_state()),
    do: {"badge-primary", gettext("Disconnected")}

  defp server_card_body(nil, _current_job, _auth, _server),
    do: gettext("No connection to this server.")

  defp server_card_body(not_connected_state(), _current_job, _auth, _server),
    do: gettext("No connection to this server.")

  defp server_card_body(connecting_state(), _current_job, _auth, _server),
    do: gettext("Connecting to the server")

  defp server_card_body(
         retry_connecting_state(
           retrying: %{retry: retry, time: time, in_seconds: in_seconds, reason: reason}
         ),
         _current_job,
         auth,
         server
       ),
       do:
         retry_connecting(%{
           auth: auth,
           server: server,
           retry: retry,
           time: time,
           in_seconds: in_seconds,
           reason: reason
         })

  defp server_card_body(connected_state(), :checking_access, _auth, _server),
    do: gettext("Checking access")

  defp server_card_body(connected_state(), :setting_up_app_user, _auth, _server),
    do: gettext("Setting up application user")

  defp server_card_body(connected_state(), :gathering_facts, _auth, _server),
    do: gettext("Gathering facts")

  defp server_card_body(connected_state(), :checking_open_ports, _auth, _server),
    do: gettext("Checking open ports")

  defp server_card_body(
         connected_state(),
         {:running_playbook, playbook, _run_id, ongoing_task},
         _auth,
         _server
       ),
       do:
         [
           case playbook do
             "setup" ->
               gettext("Setup")

             _any_other_playbook ->
               gettext("Running {playbook}", playbook: playbook)
           end,
           ongoing_task
         ]
         |> Enum.reject(&is_nil/1)
         |> Enum.join(": ")

  defp server_card_body(connected_state(), nil, _auth, _server),
    do: gettext("Connected to the server.")

  defp server_card_body(reconnecting_state(), _current_job, _auth, _server),
    do: gettext("Reconnecting to the server")

  defp server_card_body(connection_failed_state(), _current_job, _auth, _server),
    do: gettext("Could not connect to the server.")

  defp server_card_body(disconnected_state(), _current_job, _auth, _server),
    do: gettext("The connection to the server was lost.")

  defp server_card_short_status(_connection_state, _current_job, _auth, %Server{active: false}),
    do: gettext("inactive")

  defp server_card_short_status(nil, _current_job, _auth, _server),
    do: gettext("n/a")

  defp server_card_short_status(not_connected_state(), _current_job, _auth, _server),
    do: gettext("n/a")

  defp server_card_short_status(connecting_state(), _current_job, _auth, _server),
    do: gettext("connecting")

  defp server_card_short_status(
         retry_connecting_state(
           retrying: %{retry: retry, time: time, in_seconds: in_seconds, reason: reason}
         ),
         _current_job,
         auth,
         server
       ),
       do:
         retry_connecting_short(%{
           auth: auth,
           server: server,
           retry: retry,
           time: time,
           in_seconds: in_seconds,
           reason: reason
         })

  defp server_card_short_status(connected_state(), :checking_access, _auth, _server),
    do: gettext("sudo")

  defp server_card_short_status(connected_state(), :gathering_facts, _auth, _server),
    do: gettext("facts")

  defp server_card_short_status(connected_state(), :checking_open_ports, _auth, _server),
    do: gettext("ports")

  defp server_card_short_status(
         connected_state(),
         {:running_playbook, playbook, _run_id, _ongoing_task},
         _auth,
         _server
       ),
       do: playbook

  defp server_card_short_status(connected_state(), nil, _auth, _server),
    do: gettext("connected")

  defp server_card_short_status(reconnecting_state(), _current_job, _auth, _server),
    do: gettext("reconnecting")

  defp server_card_short_status(connection_failed_state(), _current_job, _auth, _server),
    do: gettext("conn. failed")

  defp server_card_short_status(disconnected_state(), _current_job, _auth, _server),
    do: gettext("conn. lost")

  defp server_card_retry_text(retry_connecting_state()), do: gettext("Retry now")
  defp server_card_retry_text(connection_failed_state()), do: gettext("Retry connecting")
  defp server_card_retry_text(_connection_state), do: nil

  defp server_connecting_or_reconnecting?(%ServerRealTimeState{
         connection_state: connecting_state()
       }),
       do: true

  defp server_connecting_or_reconnecting?(%ServerRealTimeState{
         connection_state: reconnecting_state()
       }),
       do: true

  defp server_connecting_or_reconnecting?(_state), do: false

  attr :auth, Authentication, doc: "the authentication context"
  attr :problem, :any, doc: "the problem to display"
  attr :connected, :boolean, doc: "whether the server is connected", default: false
  attr :current_job, :any, doc: "the current job of the server", default: nil

  attr :on_retry_operation, JS,
    doc: "function to call when retrying an operation",
    default: nil

  @spec server_problem(map()) :: Rendered.t()

  def server_problem(
        %{problem: {:server_ansible_playbook_failed, playbook, ansible_run_state, ansible_stats}} =
          assigns
      ) do
    details =
      [
        ansible_stats.failures > 0 &&
          gettext("{count} {count, plural, =1 {task} other {tasks}} failed",
            count: ansible_stats.failures
          ),
        ansible_stats.unreachable >= 1 && gettext("host unreachable")
      ]
      |> Enum.reject(&(&1 == false))
      |> Enum.join(", ")

    retrying =
      case assigns.current_job do
        {:running_playbook, ^playbook, _run_id, _ongoing_task} ->
          true

        _anything_else ->
          false
      end

    assigns =
      assigns
      |> assign(:playbook, playbook)
      |> assign(:ansible_run_state, ansible_run_state)
      |> assign(:details, details)
      |> assign(:retrying, retrying)

    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <Heroicons.exclamation_circle class="size-4" />
      <span>
        <%= if root?(@auth) do %>
          {gettext("Ansible playbook {ss}{cs}{playbook}{ce}{se} failed with state {cs}{state}{ce}",
            playbook: @playbook |> html_escape() |> safe_to_string(),
            state: @ansible_run_state |> inspect() |> html_escape() |> safe_to_string(),
            cs: "<code>",
            ce: "</code>",
            ss: "<strong>",
            se: "</strong>"
          )
          |> raw()}
          <%= if @details != "" do %>
            ({@details})
          <% end %>
        <% else %>
          {gettext("{cs}{playbook}{ce} provisioning task failed",
            playbook: @playbook |> html_escape() |> safe_to_string(),
            cs: "<code>",
            ce: "</code>"
          )
          |> raw()}
        <% end %>
      </span>
      <button
        :if={@on_retry_operation != nil and @connected and root?(@auth)}
        type="button"
        class="btn btn-xs btn-warning flex items-center gap-x-1 tooltip"
        data-tip="Retry"
        disabled={@current_job != nil}
        phx-click={@on_retry_operation}
        phx-value-operation="ansible-playbook"
        phx-value-playbook={@playbook}
      >
        <Heroicons.arrow_path class={["size-4", if(@retrying, do: "animate-spin")]} />
        <span class="sr-only">{gettext("Retry")}</span>
      </button>
    </div>
    """
  end

  def server_problem(%{problem: {:server_authentication_failed, :username, username}} = assigns) do
    assigns = assign(assigns, :username, username)

    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <Heroicons.exclamation_circle class="size-4" />
      <span>
        {gettext("Authentication failed for user {cs}{username}{ce}",
          username: @username |> html_escape() |> safe_to_string(),
          cs: "<code>",
          ce: "</code>"
        )
        |> raw()}
      </span>
    </div>
    """
  end

  def server_problem(
        %{problem: {:server_authentication_failed, :app_username, username}} = assigns
      ) do
    assigns = assign(assigns, :username, username)

    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <Heroicons.exclamation_circle class="size-4" />
      <span>
        <%= if root?(@auth) do %>
          {gettext("Authentication failed for application user {cs}{username}{ce}",
            username: @username |> html_escape() |> safe_to_string(),
            cs: "<code>",
            ce: "</code>"
          )
          |> raw()}
        <% else %>
          {gettext("Authentication failed")}
        <% end %>
      </span>
    </div>
    """
  end

  def server_problem(%{problem: {:server_connection_refused, host, port, username}} = assigns) do
    target =
      case {username, host, port} do
        {u, h, 22} -> "#{u}@#{:inet.ntoa(h)}"
        {u, h, p} -> "#{u}@#{:inet.ntoa(h)}:#{p}"
      end

    assigns = assign(assigns, target: target)

    ~H"""
    <div role="alert" class="alert alert-warning alert-soft">
      <Heroicons.exclamation_triangle class="size-4" />
      <span>
        {gettext("Connection refused to {cs}{target}{ce}",
          target: @target |> html_escape() |> safe_to_string(),
          cs: "<code>",
          ce: "</code>"
        )
        |> raw()}
      </span>
    </div>
    """
  end

  def server_problem(%{problem: {:server_connection_timed_out, host, port, username}} = assigns) do
    target =
      case {username, host, port} do
        {u, h, 22} -> "#{u}@#{:inet.ntoa(h)}"
        {u, h, p} -> "#{u}@#{:inet.ntoa(h)}:#{p}"
      end

    assigns = assign(assigns, target: target)

    ~H"""
    <div role="alert" class="alert alert-warning alert-soft">
      <Heroicons.exclamation_triangle class="size-4" />
      <span>
        {gettext("Timeout when connecting to {cs}{target}{ce}",
          target: @target |> html_escape() |> safe_to_string(),
          cs: "<code>",
          ce: "</code>"
        )
        |> raw()}
      </span>
    </div>
    """
  end

  def server_problem(
        %{problem: {:server_expected_property_mismatch, property, expected, actual}} = assigns
      ) do
    assigns =
      assigns
      |> assign(:property, property)
      |> assign(:expected, expected)
      |> assign(:actual, actual)

    ~H"""
    <div role="alert" class="alert alert-warning alert-soft">
      <Heroicons.exclamation_triangle class="size-4" />
      <span>{server_expected_property_mismatch(@property, @expected, @actual)}</span>
    </div>
    """
  end

  def server_problem(%{problem: {:server_fact_gathering_failed, reason}} = assigns) do
    assigns = assign(assigns, :reason, reason)

    ~H"""
    <div role="alert" class="alert alert-warning alert-soft">
      <Heroicons.exclamation_triangle class="size-4" />
      <div>
        <span>{gettext("Could not gather facts from the server")}</span>
        <%= if root?(@auth) do %>
          <div>
            {inspect(@reason)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def server_problem(
        %{problem: {:server_key_exchange_failed, unknown_fingerprint, ssh_host_key_fingerprints}} =
          assigns
      ) do
    {no_keys, valid_keys, invalid_keys} =
      case SSH.parse_ssh_host_key_fingerprints(ssh_host_key_fingerprints) do
        {:ok, valid, invalid} -> {false, valid, invalid}
        {:error, :no_keys_found} -> {true, [], []}
        {:error, {:invalid_keys, invalid_keys}} -> {false, [], invalid_keys}
      end

    assigns =
      assign(assigns,
        unknown_fingerprint: unknown_fingerprint,
        no_keys: no_keys,
        valid_keys: valid_keys,
        invalid_keys: invalid_keys
      )

    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <Heroicons.exclamation_circle class="size-4" />
      <div>
        <div class="w-full flex flex-col gap-2">
          <p><strong>{gettext("SSH key exchange failed")}</strong></p>
          <p :if={@unknown_fingerprint == nil}>{gettext("Server host key fingerprint is unknown")}</p>
          <%= if @unknown_fingerprint != [] do %>
            <p :if={@unknown_fingerprint != nil} class="mt-1">
              {gettext("The host key fingerprint provided by the server is:")}
            </p>
            <p><code class="break-all">{@unknown_fingerprint}</code></p>
          <% end %>
          <p :if={@no_keys}>{gettext("No known host key fingerprints were registered")}</p>
          <%= if @valid_keys != [] do %>
            <p>{gettext("The following host key fingerprints are registered for this server:")}</p>
            <ul class="pl-4 list-disc list-outside">
              <li :for={key <- @valid_keys}>
                <code class="break-all">{SSHKeyFingerprint.fingerprint_human(key)}</code>
                ({SSHKeyFingerprint.key_algorithm(key)})
              </li>
            </ul>
          <% end %>
          <%= if @invalid_keys != [] do %>
            <p>
              {gettext("The following invalid host key fingerprints are registered for this server:")}
            </p>
            <ul class="pl-4 list-disc list-outside">
              <li :for={{key, _error} <- @invalid_keys}>
                <code class="break-all">{key}</code>
              </li>
            </ul>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def server_problem(%{problem: {:server_missing_sudo_access, username, stderr}} = assigns) do
    assigns = assigns |> assign(:username, username) |> assign(:stderr, stderr)

    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <Heroicons.exclamation_circle class="size-4" />
      <div>
        <span>
          {gettext("User {cs}{username}{ce} does not have sudo access",
            username: @username |> html_escape() |> safe_to_string(),
            cs: "<code>",
            ce: "</code>"
          )
          |> raw()}
        </span>
        <%= if root?(@auth) do %>
          <div>
            {inspect(@stderr)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def server_problem(%{problem: {:server_open_ports_check_failed, port_problems}} = assigns) do
    port_problem_details =
      Enum.map(port_problems, fn
        {port, %Req.TransportError{reason: :econnrefused}} ->
          {port, gettext("connection refused"), nil}

        {port, %Req.TransportError{reason: :timeout}} ->
          {port, gettext("connection timeout"), nil}

        {port, unexpected_reason} ->
          {port, gettext("error"), unexpected_reason}
      end)

    retrying = assigns.current_job == :checking_open_ports

    assigns =
      assigns
      |> assign(:port_problem_details, port_problem_details)
      |> assign(:retrying, retrying)

    ~H"""
    <div role="alert" class="alert alert-warning alert-soft">
      <Heroicons.exclamation_triangle class="size-4" />
      <div class="flex flex-col gap-2">
        <p>The following ports might not be open:</p>
        <ul class="list-disc list-inside">
          <li :for={{port, message, reason} <- @port_problem_details}>
            {gettext("Port {port}: {message}", port: port, message: message)}
            <div :if={reason != nil and root?(@auth)} class="font-mono text-sm opacity-90 mt-1 mb-2">
              {inspect(reason)}
            </div>
          </li>
        </ul>
      </div>
      <button
        :if={@on_retry_operation != nil and @connected}
        type="button"
        class="btn btn-xs btn-warning flex items-center gap-x-1 tooltip"
        data-tip="Retry"
        disabled={@current_job != nil}
        phx-click={@on_retry_operation}
        phx-value-operation="check-open-ports"
      >
        <Heroicons.arrow_path class={["size-4", if(@retrying, do: "animate-spin")]} />
        <span class="sr-only">{gettext("Retry")}</span>
      </button>
    </div>
    """
  end

  def server_problem(%{problem: {:server_port_testing_script_failed, reason}} = assigns) do
    assigns = assign(assigns, :reason, reason)

    ~H"""
    <div role="alert" class="alert alert-warning alert-soft">
      <Heroicons.exclamation_triangle class="size-4" />
      <div>
        <span>{gettext("Could not check open ports on the server")}</span>
        <%= if root?(@auth) do %>
          <div>
            {inspect(@reason)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def server_problem(%{problem: {:server_sudo_access_check_failed, username, reason}} = assigns) do
    assigns = assigns |> assign(:username, username) |> assign(:reason, reason)

    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <Heroicons.exclamation_circle class="size-4" />
      <div>
        <span>
          {gettext("Could not check whether {cs}{username}{ce} has sudo access",
            username: @username |> html_escape() |> safe_to_string(),
            cs: "<code>",
            ce: "</code>"
          )
          |> raw()}
        </span>
        <%= if root?(@auth) do %>
          <div>
            {inspect(@reason)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def server_problem(%{problem: {:server_reconnection_failed, reason}} = assigns) do
    assigns = assign(assigns, :reason, reason)

    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <Heroicons.exclamation_circle class="size-4" />
      <div>
        <span>{gettext("Could not reconnect to server after setup")}</span>
        <%= if root?(@auth) do %>
          <div>
            {inspect(@reason)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def server_problem(assigns) do
    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <Heroicons.exclamation_circle class="size-4" />
      <div>
        <span>{gettext("Oops, an unexpected problem occurred")}</span>
        <%= if root?(@auth) do %>
          <div>
            {inspect(@problem)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp server_expected_property_mismatch(:cpus, expected, actual),
    do:
      gettext(
        "Server has {actual} {actual, plural, =1 {CPU} other {CPUs}} when it should have {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(:cores, expected, actual),
    do:
      gettext(
        "Server has {actual} CPU {actual, plural, =1 {core} other {cores}} when it should have {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(:vcpus, expected, actual),
    do:
      gettext(
        "Server has {actual} {actual, plural, =1 {vCPU} other {vCPUs}} when it should have {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(:memory, expected, actual),
    do:
      gettext("Server has {actual} MB of RAM when it should have {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(:swap, expected, actual),
    do:
      gettext("Server has {actual} MB of swap when it should have {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(:system, expected, actual),
    do:
      gettext("Server is running a system of type {actual} when it should be {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(:architecture, expected, actual),
    do:
      gettext("Server is running on architecture {actual} when it should be {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(:os_family, expected, actual),
    do:
      gettext(
        "Server is running an operating system of the {actual} family when it should be {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(:distribution, expected, actual),
    do:
      gettext("Server is running the {actual} Linux distribution when it should be {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(:distribution_release, expected, actual),
    do:
      gettext("Server is running distribution release {actual} when it should be {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(:distribution_version, expected, actual),
    do:
      gettext("Server is running distribution version {actual} when it should be {expected}",
        actual: actual,
        expected: expected
      )

  defp server_expected_property_mismatch(property, expected, actual),
    do:
      gettext("Server property {property} has value {actual} when it should be {expected}",
        actual: actual,
        expected: expected,
        property: Atom.to_string(property)
      )

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
    <%= if @reason == :econnrefused do %>
      {gettext("Server unreachable.")}
    <% end %>
    <%= if @reason == :timeout do %>
      {gettext("Connection timed out.")}
    <% end %>
    <span
      id={@id}
      data-end-time={DateTime.to_iso8601(@end_time)}
      data-template={gettext("Will retry in '{seconds}'s")}
      data-template-done={gettext("Will retry soon")}
      phx-hook="remainingSeconds"
    >
      {gettext("Will retry in {count}s", count: @remaining_seconds)}
    </span>
    <%= if root?(@auth) do %>
      ({gettext("attempt #\{count\}", count: @retry + 1)})
    <% end %>
    """
  end

  defp retry_connecting_short(assigns) do
    id = "server-#{assigns.server.id}-retry-connecting-short"

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
    <span
      id={@id}
      data-end-time={DateTime.to_iso8601(@end_time)}
      data-template={gettext("retry '{seconds}'s")}
      data-template-done={gettext("retry soon")}
      phx-hook="remainingSeconds"
    >
      {gettext("retry {count}s", count: @remaining_seconds)}
    </span>
    <%= if root?(@auth) do %>
      ({gettext("#\{count\}", count: @retry + 1)})
    <% end %>
    """
  end

  @spec server_owner_name(Server.t()) :: String.t()
  def server_owner_name(server) do
    case server do
      %Server{owner: %ServerOwner{group_member: %ServerGroupMember{username: username}}} ->
        username

      %Server{owner: %ServerOwner{username: username}} when is_binary(username) ->
        username

      %Server{username: username} ->
        username
    end
  end
end
