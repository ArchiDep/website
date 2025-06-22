defmodule ArchiDepWeb.Servers.ServerComponents do
  use Phoenix.Component

  import ArchiDep.Servers.ServerConnectionState
  import ArchiDepWeb.Helpers.AuthHelpers
  import ArchiDepWeb.Helpers.I18nHelpers
  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Schemas.Server
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
    {card_class, badge_class, badge_text, status_text, retry_text} =
      case assigns.state do
        nil ->
          {"bg-neutral text-neutral-content", "badge-info", "Not connected",
           "No connection to this server.", nil}

        %ServerRealTimeState{connection_state: :not_connected} ->
          {"bg-neutral text-neutral-content", "badge-info", "Not connected",
           "No connection to this server.", nil}

        %ServerRealTimeState{connection_state: connecting_state()} ->
          {"bg-info text-info-content animate-pulse", "badge-primary", "Connecting",
           "Connecting to the server", nil}

        %ServerRealTimeState{
          connection_state:
            retry_connecting_state(
              retrying: %{retry: retry, time: time, in_seconds: in_seconds, reason: reason}
            )
        } ->
          {"bg-info text-info-content", "badge-primary", "Reconnecting",
           retry_connecting(%{
             auth: assigns.auth,
             server: assigns.server,
             retry: retry,
             time: time,
             in_seconds: in_seconds,
             reason: reason
           }), "Retry now"}

        %ServerRealTimeState{connection_state: connected_state(), current_job: current_job} ->
          {
            "bg-success text-success-content",
            "badge-success",
            "Connected",
            case current_job do
              :checking_access ->
                "Checking access"

              :setting_up_app_user ->
                "Setting up application user"

              :gathering_facts ->
                "Gathering facts"

              {:running_playbook, playbook, _run_id, ongoing_task} ->
                [
                  case playbook do
                    "setup" ->
                      "Initial setup"

                    _any_other_playbook ->
                      "Running #{playbook}"
                  end,
                  ongoing_task
                ]
                |> Enum.reject(&is_nil/1)
                |> Enum.join(": ")

              nil ->
                "Connected to the server."
            end,
            nil
          }

        %ServerRealTimeState{connection_state: reconnecting_state()} ->
          {"bg-info text-info-content animate-pulse", "badge-primary", "Reconnecting",
           "Reconnecting to the server", nil}

        %ServerRealTimeState{connection_state: connection_failed_state()} ->
          {"bg-error text-error-content", "badge-error", "Connection failed",
           "Could not connect to the server.", "Retry connecting"}

        %ServerRealTimeState{connection_state: disconnected_state()} ->
          {"bg-info text-info-content", "badge-primary", "Disconnected",
           "The connection to the server was lost.", nil}
      end

    assigns =
      assigns
      |> assign(:card_class, card_class)
      |> assign(:badge_class, badge_class)
      |> assign(:badge_text, badge_text)
      |> assign(:status_text, status_text)
      |> assign(:retry_text, retry_text)
      |> assign(:connected, connected?(assigns.state.connection_state))
      |> assign(:busy, assigns.state.current_job != nil)

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
          <Heroicons.check_circle :if={!@busy} class="size-4" />
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
          ["#{ansible_stats.failures} #{pluralize(ansible_stats.failures, "task")} failed"]
      else
        details
      end

    details =
      if ansible_stats.unreachable >= 1 do
        details ++ ["host unreachable"]
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
          Ansible playbook <code>{@playbook}</code>
          failed with state <code>{inspect(@ansible_run_state)}</code>
          <%= if @details != [] do %>
            ({Enum.join(@details, ", ")})
          <% end %>
        <% else %>
          <code>{@playbook}</code> provisioning task failed
        <% end %>
      </span>
      <%= if @on_retry_operation != nil and @connected and has_role?(@auth, :root) do %>
        <button
          type="button"
          class="btn btn-xs btn-warning flex items-center gap-x-1"
          disabled={@current_job != nil}
          phx-click={@on_retry_operation}
          phx-value-operation="ansible-playbook"
          phx-value-playbook={@playbook}
        >
          <Heroicons.arrow_path class={["size-4", if(@retrying, do: "animate-spin")]} />
          <span>Retry</span>
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
      <Heroicons.exclamation_circle class="size-4" />
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
        <span>Could not gather facts from the server</span>
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
        <span>User <code>{@username}</code> does not have <code>sudo</code> access</span>
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
        <span>Could not check whether <code>{@username}</code> has <code>sudo</code> access</span>
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
        <span>Could not reconnect to server after setup</span>
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
        <span>Oops, an unexpected problem occurred</span>
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
    do: "Server has #{actual} CPU(s) when it should have #{expected}"

  defp server_expected_property_mismatch(:cores, expected, actual),
    do: "Server has #{actual} CPU core(s) when it should have #{expected}"

  defp server_expected_property_mismatch(:vcpus, expected, actual),
    do: "Server has #{actual} vCPU(s) when it should have #{expected}"

  defp server_expected_property_mismatch(:memory, expected, actual),
    do: "Server has #{actual} MB of RAM when it should have #{expected}"

  defp server_expected_property_mismatch(:swap, expected, actual),
    do: "Server has #{actual} MB of swap when it should have #{expected}"

  defp server_expected_property_mismatch(:system, expected, actual),
    do: "Server is running a #{actual} system when it should be #{expected}"

  defp server_expected_property_mismatch(:architecture, expected, actual),
    do: "Server is running on an #{actual} architecture when it should be #{expected}"

  defp server_expected_property_mismatch(:os_family, expected, actual),
    do:
      "Server is running an operating system of the #{actual} family when it should be #{expected}"

  defp server_expected_property_mismatch(:distribution, expected, actual),
    do: "Server is running the #{actual} Linux distribution when it should be #{expected}"

  defp server_expected_property_mismatch(:distribution_release, expected, actual),
    do: "Server is running distribution release #{actual} when it should be #{expected}"

  defp server_expected_property_mismatch(:distribution_version, expected, actual),
    do: "Server is running distribution version #{actual} when it should be #{expected}"

  defp server_expected_property_mismatch(property, expected, actual),
    do: "Server has #{actual} #{Atom.to_string(property)} when it should have #{expected}"

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
      Server unreachable.
    <% end %>
    Will retry
    <span id={@id} data-end-time={DateTime.to_iso8601(@end_time)} phx-hook="remainingSeconds">
      in {@remaining_seconds}s
    </span>
    <%= if has_role?(@auth, :root) do %>
      (attempt #{@retry + 1})
    <% end %>
    """
  end
end
