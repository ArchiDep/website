defmodule ArchiDepWeb.Servers.ServerHelpComponent do
  @moduledoc """
  A component that provides help and troubleshooting tips for servers,
  displaying common issues and solutions related to server setup and connection
  problems.
  """

  use ArchiDepWeb, :component

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Servers.ServerTracking.ServerProblems
  alias ArchiDep.Authentication
  alias ArchiDep.Course.Material
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState

  attr :auth, Authentication, doc: "the authentication context", required: true
  attr :server, Server, doc: "the server for which help is provided", required: true
  attr :state, ServerRealTimeState, doc: "the current state of the server", default: nil

  @spec server_help(map()) :: Rendered.t()
  def server_help(assigns) do
    ~H"""
    <!-- Inactive server -->
    <.troubleshooting_note :if={@server.set_up_at == nil and not @server.active} class="!my-0">
      <p>
        <strong>Oops.</strong> It appears that you have mistakenly created your
        server in an inactive state. We will only connect to servers that are
        marked as active.
      </p>
    </.troubleshooting_note>
    <!-- Connection timeout -->
    <.troubleshooting_note
      :if={
        @server.set_up_at == nil and @server.active and @state != nil and
          (connecting?(@state.connection_state) or retry_connecting?(@state.connection_state)) and
          problem?(@state, :server_connection_timed_out)
      }
      class="!my-0"
    >
      <p>
        <strong>Oops.</strong> We can't seem to connect to your server. This
        could be due to a misconfiguration or an issue with the server itself.
        Please check the following:
      </p>
      <ul class="mt-2 list-disc list-outside pl-6 flex flex-col gap-y-2">
        <li>Did you configure the correct IP address?</li>
        <li>
          We are attempting to open an SSH connection to port {@server.ssh_port ||
            22}. Is this port open in your cloud provider's firewall?
        </li>
        <li>
          Is your server running? We can't connect to it if it's off.
          (<a
            href="https://youtu.be/5UT8RkSmN4k?feature=shared"
            target="_blank"
            class="no-hover italic"
          >Have you tried turning it off and on again?</a>)
        </li>
      </ul>
    </.troubleshooting_note>
    <!-- Connection refused -->
    <.troubleshooting_note
      :if={
        @server.set_up_at == nil and @server.active and @state != nil and
          (connecting?(@state.connection_state) or retry_connecting?(@state.connection_state)) and
          problem?(@state, :server_connection_refused)
      }
      class="!my-0"
    >
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
    <.troubleshooting_note
      :if={
        @server.set_up_at == nil and @server.active and @state != nil and
          connection_failed?(@state.connection_state) and
          problem?(@state, :server_authentication_failed)
      }
      class="!my-0"
    >
      <p>
        <strong>Oops.</strong> We've reached an SSH server at the IP address and
        port you provided, but it's not letting us in with the username you
        provided.
      </p>
      <ul class="mt-2 list-disc list-outside pl-6 flex flex-col gap-y-2">
        <li>
          Did you configure the correct username? We might be trying to log in
          with the wrong user. We need the
          <a
            href={"#{Material.run_virtual_server_exercise().url}#exclamation-give-the-teacher-access-to-your-virtual-machine"}
            class="underline hover:no-underline"
            target="_blank"
          >
            username you configured as the administrator account
          </a>
          when you set up your server.
        </li>
        <li>
          Did you <a
            href={"#{Material.run_virtual_server_exercise().url}#exclamation-give-the-teacher-access-to-your-virtual-machine"}
            class="underline hover:no-underline"
            target="_blank"
          >add the course's SSH public key to your user's authorized keys</a>?
          We won't be able to log in without it. Make sure to copy the entire
          command from the exercise and to replace `jde` with your own username
          before running it on your server.
        </li>
      </ul>
    </.troubleshooting_note>
    <!-- Key exchange failure -->
    <.troubleshooting_note
      :if={
        @server.active and @state != nil and
          connection_failed?(@state.connection_state) and
          problem?(@state, :server_key_exchange_failed)
      }
      class="!my-0"
    >
      <p>
        <strong>Oops.</strong> We've reached an SSH server at the IP address and
        port you provided, but the public SSH key fingerprint it provided does
        not match those you have registered. That means we can't be sure we're
        connecting to the right server.
      </p>
      <ul class="mt-2 list-disc list-outside pl-6 flex flex-col gap-y-2">
        <li>
          <div class="flex flex-col gap-2">
            <span>
              Most likely the problem is due to user error.
              When setting up your virtual server, did you <a
                href={"#{Material.run_virtual_server_exercise().url}#exclamation-register-your-azure-vm-with-us"}
                class="underline hover:no-underline"
                target="_blank"
              >give us the correct SSH host
              key fingerprints</a>? You need to connect to your server with SSH and
              run the following command:
            </span>
            <code>find /etc/ssh -name "ssh_host_*.pub" -exec ssh-keygen -lf {"{}"} \;</code>
            <span>
              Copy the output of that command, edit your server, and make sure
              to paste them into the <strong>SSH host key fingerprints</strong>
              field and save. You may then attempt to reconnect.
            </span>
          </div>
        </li>
        <li>
          If the problem persists, let us know!  It's also possible there is an
          incompatibility between your SSH server and our SSH client. This is
          unlikely if you set up your server as we requested, but <em>shit
          happens</em>™.
          <em class="text-base-content/50">Or it might just be a bug on our end...</em>
        </li>
      </ul>
    </.troubleshooting_note>
    <!-- Property mismatches -->
    <.troubleshooting_note
      :if={
        @server.active and @state != nil and
          connected?(@state.connection_state) and
          problem?(@state, :server_expected_property_mismatch)
      }
      class="!my-0"
    >
      <p>
        <strong>Oops.</strong>
        We've successfully connected to your server, but
        it appears that it does not meet the expected configuration. You may
        have missed a step in the <a
          href={Material.run_virtual_server_exercise().url}
          class="underline hover:no-underline"
          target="_blank"
        >virtual server setup exercise</a>. Please check the following:
      </p>
      <ul class="mt-2 list-disc list-outside pl-6 flex flex-col gap-y-2">
        <li :if={mismatch?(@state, &(&1 not in [:hostname, :swap]))}>
          The hardware and/or operating system of your server does not match the
          expected values. Did you <a
            href={"#{Material.run_virtual_server_exercise().url}#exclamation-configure-basic-settings"}
            class="underline hover:no-underline"
            target="_blank"
          >choose the correct image and size when configuring the basic settings</a>?
        </li>
        <li :if={mismatch?(@state, :hostname)}>
          The hostname of your server does not match the expected value.
          Did you <a
            href={"#{Material.run_virtual_server_exercise().url}#exclamation-change-the-hostname-of-your-virtual-machine"}
            class="underline hover:no-underline"
            target="_blank"
          >configure the correct hostname for your server</a>?
        </li>
        <li :if={mismatch?(@state, :swap)}>
          Your server does not appear to have the expected amount of swap space. Did you <a
            href={"#{Material.run_virtual_server_exercise().url}#exclamation-add-swap-space-to-your-virtual-server"}
            class="underline hover:no-underline"
            target="_blank"
          >add swap space as instructed</a>?
        </li>
      </ul>
    </.troubleshooting_note>
    <!-- Open port check failed -->
    <.troubleshooting_note
      :if={
        @server.active and @state != nil and
          connected?(@state.connection_state) and
          problem?(@state, :server_open_ports_check_failed)
      }
      class="!my-0"
    >
      <p>
        <strong>Oops.</strong>
        We've connected to your server but we can't seem
        to reach some of the ports that should be open. Are you sure you <a
          href={"#{Material.run_virtual_server_exercise().url}#exclamation-configure-open-ports"}
          class="underline hover:no-underline"
          target="_blank"
        >
          opened
          the required ports in your cloud provider's firewall
        </a>?
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
        server and are ready to go. You can now use it for exercises.
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

  defp mismatch?(%ServerRealTimeState{problems: problems}, property) when is_atom(property),
    do: Enum.any?(problems, server_expected_property_mismatch_problem?(property))

  defp mismatch?(%ServerRealTimeState{problems: problems}, predicate)
       when is_function(predicate, 1),
       do: Enum.any?(problems, server_expected_property_mismatch_problem?(predicate))
end
