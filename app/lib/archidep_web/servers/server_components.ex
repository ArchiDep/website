defmodule ArchiDepWeb.Servers.ServerComponents do
  use ArchiDepWeb, :component

  import ArchiDep.Servers.ServerConnectionState
  import ArchiDepWeb.Helpers.AuthHelpers
  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias Phoenix.LiveView.JS

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

  attr :on_retry_connection, JS,
    doc: "JS command to execute when retrying the connection",
    default: nil

  attr :on_retry_operation, JS,
    doc: "function to call when retrying an operation",
    default: nil

  def server_card(assigns) do
    state = assigns.state

    {badge_class, badge_text, status_text, retry_text, connecting_or_reconnecting} =
      case state do
        nil ->
          {"badge-info", gettext("Not connected"), gettext("No connection to this server."), nil,
           false}

        %ServerRealTimeState{connection_state: not_connected_state()} ->
          {"badge-info", gettext("Not connected"), gettext("No connection to this server."), nil,
           false}

        %ServerRealTimeState{connection_state: connecting_state()} ->
          {"badge-primary", gettext("Connecting"), gettext("Connecting to the server"), nil, true}

        %ServerRealTimeState{
          connection_state:
            retry_connecting_state(
              retrying: %{retry: retry, time: time, in_seconds: in_seconds, reason: reason}
            )
        } ->
          {"badge-primary", gettext("Reconnecting"),
           retry_connecting(%{
             auth: assigns.auth,
             server: assigns.server,
             retry: retry,
             time: time,
             in_seconds: in_seconds,
             reason: reason
           }), gettext("Retry now"), false}

        %ServerRealTimeState{connection_state: connected_state(), current_job: current_job} ->
          {
            "badge-success",
            gettext("Connected"),
            case current_job do
              :checking_access ->
                gettext("Checking access")

              :setting_up_app_user ->
                gettext("Setting up application user")

              :gathering_facts ->
                gettext("Gathering facts")

              {:running_playbook, playbook, _run_id, ongoing_task} ->
                [
                  case playbook do
                    "setup" ->
                      gettext("Initial setup")

                    _any_other_playbook ->
                      gettext("Running {playbook}", playbook: playbook)
                  end,
                  ongoing_task
                ]
                |> Enum.reject(&is_nil/1)
                |> Enum.join(": ")

              nil ->
                gettext("Connected to the server.")
            end,
            nil,
            false
          }

        %ServerRealTimeState{connection_state: reconnecting_state()} ->
          {"badge-primary", gettext("Reconnecting"), gettext("Reconnecting to the server"), nil,
           true}

        %ServerRealTimeState{connection_state: connection_failed_state()} ->
          {"badge-error", gettext("Connection failed"),
           gettext("Could not connect to the server."), gettext("Retry connecting"), false}

        %ServerRealTimeState{connection_state: disconnected_state()} ->
          {"badge-primary", gettext("Disconnected"),
           gettext("The connection to the server was lost."), nil, false}
      end

    filtered_problems =
      case state do
        nil ->
          []

        %ServerRealTimeState{set_up_at: nil} ->
          state.problems

        %ServerRealTimeState{} ->
          # Ignore connection timeout problems after the server has been set up.
          # The server might simply be offline.
          Enum.reject(
            state.problems,
            &match?({:server_connection_timed_out, _host, _port, _user_type, _username}, &1)
          )
      end

    card_class =
      case {state, filtered_problems} do
        {nil, _problems} ->
          "bg-neutral text-neutral-content"

        {%ServerRealTimeState{connection_state: not_connected_state()}, _problems} ->
          "bg-neutral text-neutral-content"

        {%ServerRealTimeState{connection_state: connecting_state()}, []} ->
          "bg-info text-info-content animate-pulse"

        {%ServerRealTimeState{connection_state: connecting_state()}, _problems} ->
          "bg-warning text-warning-content animate-pulse"

        {%ServerRealTimeState{connection_state: retry_connecting_state()}, []} ->
          "bg-info text-info-content"

        {%ServerRealTimeState{connection_state: retry_connecting_state()}, _problems} ->
          "bg-warning text-warning-content"

        {%ServerRealTimeState{connection_state: connected_state()}, []} ->
          "bg-success text-success-content"

        {%ServerRealTimeState{connection_state: connected_state()}, _problems} ->
          "bg-warning text-warning-content"

        {%ServerRealTimeState{connection_state: reconnecting_state()}, []} ->
          "bg-info text-info-content animate-pulse"

        {%ServerRealTimeState{connection_state: reconnecting_state()}, _problems} ->
          "bg-warning text-warning-content animate-pulse"

        {%ServerRealTimeState{connection_state: connection_failed_state()}, _problems} ->
          "bg-error text-error-content"

        {%ServerRealTimeState{connection_state: disconnected_state()}, []} ->
          "bg-info text-info-content"

        {%ServerRealTimeState{connection_state: disconnected_state()}, _problems} ->
          "bg-warning text-warning-content"
      end

    assigns =
      assigns
      |> assign(:card_class, card_class)
      |> assign(:badge_class, badge_class)
      |> assign(:badge_text, badge_text)
      |> assign(:status_text, status_text)
      |> assign(:retry_text, retry_text)
      |> assign(:connected, state != nil and connected?(state.connection_state))
      |> assign(:connecting_or_reconnecting, connecting_or_reconnecting)
      |> assign(:busy, state != nil and state.current_job != nil)

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
        <div class="flex items-center gap-x-2">
          <Heroicons.bolt :if={!@busy and (@connected or @connecting_or_reconnecting)} class="size-4" />
          <Heroicons.bolt_slash
            :if={!@busy and !@connected and !@connecting_or_reconnecting}
            class="size-4"
          />
          <Heroicons.arrow_path :if={@busy} class="size-4 animate-spin" />
          <span>{@status_text}</span>
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
        <div :if={@retry_text != nil and @on_retry_connection != nil} class="card-actions justify-end">
          <button
            type="button"
            class="btn btn-sm btn-secondary"
            phx-click={@on_retry_connection |> JS.add_class("btn-disabled")}
          >
            {@retry_text}
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :auth, Authentication, doc: "the authentication context"
  attr :problem, :any, doc: "the problem to display"
  attr :connected, :boolean, doc: "whether the server is connected", default: false
  attr :current_job, :any, doc: "the current job of the server", default: nil

  attr :on_retry_operation, JS,
    doc: "function to call when retrying an operation",
    default: nil

  def server_problem(
        %{problem: {:server_ansible_playbook_failed, playbook, ansible_run_state, ansible_stats}} =
          assigns
      ) do
    assigns =
      assigns
      |> assign(:playbook, playbook)
      |> assign(:ansible_run_state, ansible_run_state)

    details = []

    details =
      if ansible_stats.failures > 0 do
        details ++
          [
            gettext("{count} {count, plural, =1 {task} other {tasks}} failed",
              count: ansible_stats.failures
            )
          ]
      else
        details
      end

    details =
      if ansible_stats.unreachable >= 1 do
        details ++ [gettext("host unreachable")]
      else
        details
      end

    retrying =
      case assigns.current_job do
        {:running_playbook, ^playbook, _run_id, _ongoing_task} ->
          true

        _anything_else ->
          false
      end

    assigns = assigns |> assign(:details, details) |> assign(:retrying, retrying)

    ~H"""
    <div role="alert" class="alert alert-error alert-soft">
      <Heroicons.exclamation_circle class="size-4" />
      <span>
        <%= if has_role?(@auth, :root) do %>
          {gettext("Ansible playbook {ss}{cs}{playbook}{ce}{se} failed with state {cs}{state}{ce}",
            playbook: @playbook |> html_escape() |> safe_to_string(),
            state: @ansible_run_state |> inspect() |> html_escape() |> safe_to_string(),
            cs: "<code>",
            ce: "</code>",
            ss: "<strong>",
            se: "</strong>"
          )
          |> raw()}
          <%= if @details != [] do %>
            ({Enum.join(@details, ", ")})
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
      <%= if @on_retry_operation != nil and @connected and has_role?(@auth, :root) do %>
        <button
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
      <% end %>
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
        <%= if has_role?(@auth, :root) do %>
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

  def server_problem(
        %{problem: {:server_connection_timed_out, host, port, _user_type, username}} = assigns
      ) do
    assigns =
      assigns
      |> assign(:host, :inet.ntoa(host))
      |> assign(:port, port)
      |> assign(:username, username)

    ~H"""
    <div role="alert" class="alert alert-warning alert-soft">
      <Heroicons.exclamation_triangle class="size-4" />
      <span>
        {gettext("Timeout when connecting to {cs}{target}{ce}",
          target: "#{@username}@#{@host}:#{@port}" |> html_escape() |> safe_to_string(),
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
        <%= if has_role?(@auth, :root) do %>
          <div>
            {inspect(@reason)}
          </div>
        <% end %>
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
        <%= if has_role?(@auth, :root) do %>
          <div>
            {inspect(@stderr)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def server_problem(%{problem: {:server_sudo_access_check_failed, reason}} = assigns) do
    assigns = assign(assigns, :reason, reason)

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
        <%= if has_role?(@auth, :root) do %>
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
        <%= if has_role?(@auth, :root) do %>
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
        <%= if has_role?(@auth, :root) do %>
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
    <%= if has_role?(@auth, :root) do %>
      ({gettext("attempt #\{count\}", count: @retry + 1)})
    <% end %>
    """
  end

  attr :properties, ServerProperties, doc: "the server properties to display"

  def expected_server_properties(assigns) do
    ~H"""
    <li :if={expected_cpu(@properties) != ""}>
      {expected_cpu(@properties)}
    </li>
    <li :if={expected_memory(@properties) != ""}>
      {expected_memory(@properties)}
    </li>
    <li :if={expected_os(@properties) != ""}>
      {expected_os(@properties)}
    </li>
    <li :if={expected_distribution(@properties) != ""}>
      {expected_distribution(@properties)}
    </li>
    """
  end

  defp expected_cpu(properties) do
    [
      if(properties.cpus != nil,
        do:
          gettext("{count} {count, plural, =1 {CPU} other {CPUs}}",
            count: properties.cpus
          ),
        else: nil
      ),
      if(properties.cores != nil,
        do:
          gettext("{count} {count, plural, =1 {core} other {cores}}",
            count: properties.cores
          ),
        else: nil
      ),
      if(properties.vcpus != nil,
        do:
          gettext("{count} {count, plural, =1 {vCPU} other {vCPUs}}",
            count: properties.vcpus
          ),
        else: nil
      )
    ]
    |> Enum.reject(&Kernel.is_nil/1)
    |> Enum.join(", ")
  end

  defp expected_memory(properties) do
    [
      {gettext("RAM"), properties.memory},
      {gettext("Swap"), properties.swap}
    ]
    |> Enum.filter(fn {_, value} -> value != nil end)
    |> Enum.map(fn {label, value} -> "#{value} MB #{label}" end)
    |> Enum.join(", ")
  end

  defp expected_os(properties) do
    system_and_arch =
      [
        properties.system,
        properties.architecture
      ]
      |> Enum.filter(&(&1 != nil))
      |> Enum.join(" ")

    os_family =
      case properties.os_family do
        nil -> nil
        os_family -> gettext("{os_family} family", os_family: os_family)
      end

    [system_and_arch, os_family]
    |> Enum.filter(&(&1 != nil and &1 != ""))
    |> Enum.join(", ")
  end

  defp expected_distribution(properties) do
    [
      properties.distribution,
      properties.distribution_version,
      properties.distribution_release
    ]
    |> Enum.filter(&(&1 != nil))
    |> Enum.join(" ")
  end
end
