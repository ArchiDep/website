defmodule ArchiDepWeb.Servers.ServerHelpComponentTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Servers.ServerHelpComponent

  @nothing %{
    inactive: nil,
    timeout: nil,
    refused: nil,
    auth_failed: nil,
    key_exchange: nil,
    property_mismatch: nil,
    open_ports: nil,
    success: false
  }

  @exercise "/course/402-run-virtual-server/"
  @create_your_server @exercise <> "#create-your-server"
  @administrator_account @exercise <> "#configure-your-administrator-account"
  @teacher_access @exercise <> "#give-the-teacher-access-to-your-virtual-machine"
  @fingerprints @exercise <> "#register-your-azure-vm-with-us"
  @basic_settings @exercise <> "#configure-basic-settings"
  @hostname @exercise <> "#change-the-hostname-of-your-virtual-machine"
  @swap @exercise <> "#add-swap-space-to-your-virtual-server"
  @open_ports @exercise <> "#configure-open-ports"
  @firewall @exercise <> "#i-forgot-to-open-some-or-all-of-the-ports-in-the-firewall"
  @it_crowd "https://youtu.be/5UT8RkSmN4k?feature=shared"

  describe "server_help/1" do
    test "tells the student to activate a mistakenly inactive server" do
      server = ServersFactory.build(:server_view, set_up_at: nil, active: false)

      assert server_help(server, nil) == %{@nothing | inactive: %{links: []}}
    end

    test "shows connection-timeout help with the configured SSH port while connecting" do
      server = ServersFactory.build(:server_view, set_up_at: nil, active: true, ssh_port: 2222)

      state =
        real_time_state(ServersFactory.random_connecting_state(),
          problems: [timeout_problem()]
        )

      assert server_help(server, state) ==
               %{@nothing | timeout: %{ssh_port: 2222, links: [@create_your_server, @it_crowd]}}
    end

    test "shows connection-timeout help with the default SSH port while reconnecting" do
      server = ServersFactory.build(:server_view, set_up_at: nil, active: true, ssh_port: nil)

      state =
        real_time_state(ServersFactory.random_retry_connecting_state(),
          problems: [timeout_problem()]
        )

      assert server_help(server, state) ==
               %{@nothing | timeout: %{ssh_port: 22, links: [@create_your_server, @it_crowd]}}
    end

    test "shows connection-refused help while connecting" do
      server = ServersFactory.build(:server_view, set_up_at: nil, active: true)

      state =
        real_time_state(ServersFactory.random_connecting_state(),
          problems: [refused_problem()]
        )

      assert server_help(server, state) ==
               %{@nothing | refused: %{links: [@create_your_server]}}
    end

    test "shows authentication-failure help when the connection failed" do
      server = ServersFactory.build(:server_view, set_up_at: nil, active: true)

      state =
        real_time_state(ServersFactory.random_connection_failed_state(),
          problems: [auth_problem()]
        )

      assert server_help(server, state) ==
               %{@nothing | auth_failed: %{links: [@administrator_account, @teacher_access]}}
    end

    test "shows key-exchange help even for an already set-up server" do
      server =
        ServersFactory.build(:server_view, set_up_at: ~U[2026-06-01 08:00:00Z], active: true)

      state =
        real_time_state(ServersFactory.random_connection_failed_state(),
          problems: [key_exchange_problem()]
        )

      assert server_help(server, state) ==
               %{@nothing | key_exchange: %{links: [@fingerprints]}}
    end

    test "points at the hardware step for a non-hostname, non-swap mismatch" do
      assert mismatch_help(:cpus) ==
               %{
                 @nothing
                 | property_mismatch: %{
                     hardware: true,
                     hostname: false,
                     swap: false,
                     links: [@exercise, @basic_settings]
                   }
               }
    end

    test "points at the hostname step for a hostname mismatch" do
      assert mismatch_help(:hostname) ==
               %{
                 @nothing
                 | property_mismatch: %{
                     hardware: false,
                     hostname: true,
                     swap: false,
                     links: [@exercise, @hostname]
                   }
               }
    end

    test "points at the swap step for a swap mismatch" do
      assert mismatch_help(:swap) ==
               %{
                 @nothing
                 | property_mismatch: %{
                     hardware: false,
                     hostname: false,
                     swap: true,
                     links: [@exercise, @swap]
                   }
               }
    end

    test "points at every relevant step for combined mismatches" do
      server = ServersFactory.build(:server_view, set_up_at: nil, active: true)

      state =
        real_time_state(ServersFactory.random_connected_state(),
          problems: [
            mismatch_problem(:cpus),
            mismatch_problem(:hostname),
            mismatch_problem(:swap)
          ]
        )

      assert server_help(server, state) == %{
               @nothing
               | property_mismatch: %{
                   hardware: true,
                   hostname: true,
                   swap: true,
                   links: [@exercise, @basic_settings, @hostname, @swap]
                 }
             }
    end

    test "shows open-ports help when connected" do
      server = ServersFactory.build(:server_view, set_up_at: nil, active: true)

      state =
        real_time_state(ServersFactory.random_connected_state(),
          problems: [open_ports_problem()]
        )

      assert server_help(server, state) ==
               %{@nothing | open_ports: %{links: [@open_ports, @firewall]}}
    end

    test "congratulates the student once the server is set up and connected" do
      server =
        ServersFactory.build(:server_view, set_up_at: ~U[2026-06-01 08:00:00Z], active: true)

      state = real_time_state(ServersFactory.random_connected_state())

      assert server_help(server, state) == %{@nothing | success: true}
    end

    test "withholds congratulations while the server is busy" do
      server =
        ServersFactory.build(:server_view, set_up_at: ~U[2026-06-01 08:00:00Z], active: true)

      state =
        real_time_state(ServersFactory.random_connected_state(), current_job: :checking_access)

      assert server_help(server, state) == @nothing
    end

    test "withholds congratulations while an unhandled problem remains" do
      server =
        ServersFactory.build(:server_view, set_up_at: ~U[2026-06-01 08:00:00Z], active: true)

      state =
        real_time_state(ServersFactory.random_connected_state(),
          problems: [{:server_fact_gathering_failed, "boom"}]
        )

      assert server_help(server, state) == @nothing
    end

    test "shows nothing while connecting without a recognised problem" do
      server = ServersFactory.build(:server_view, set_up_at: nil, active: true)
      state = real_time_state(ServersFactory.random_connecting_state())

      assert server_help(server, state) == @nothing
    end

    test "withholds connection-timeout help once the connection succeeds" do
      server = ServersFactory.build(:server_view, set_up_at: nil, active: true)

      state =
        real_time_state(ServersFactory.random_connected_state(),
          problems: [timeout_problem()]
        )

      assert server_help(server, state) == @nothing
    end
  end

  defp mismatch_help(property) do
    server = ServersFactory.build(:server_view, set_up_at: nil, active: true)

    state =
      real_time_state(ServersFactory.random_connected_state(),
        problems: [mismatch_problem(property)]
      )

    server_help(server, state)
  end

  # The component does not branch on the authentication context, so a fresh
  # student principal is sufficient for every case.
  defp server_help(server, state) do
    html =
      render_component(&ServerHelpComponent.server_help/1,
        auth: Factory.build(:authentication, root: false),
        server: server,
        state: state
      )

    notes = html |> find_html_elements(".note-troubleshooting") |> Map.new(&{classify(&1), &1})

    %{
      inactive: notes |> Map.get(:inactive) |> links_detail(),
      timeout: notes |> Map.get(:timeout) |> timeout_detail(),
      refused: notes |> Map.get(:refused) |> links_detail(),
      auth_failed: notes |> Map.get(:auth_failed) |> links_detail(),
      key_exchange: notes |> Map.get(:key_exchange) |> links_detail(),
      property_mismatch: notes |> Map.get(:property_mismatch) |> property_mismatch_detail(),
      open_ports: notes |> Map.get(:open_ports) |> links_detail(),
      success: find_html_elements(html, ".alert-success") != []
    }
  end

  defp classify(note) do
    text = html_element_text(note)

    cond do
      text =~ "inactive state" -> :inactive
      text =~ "can't seem to connect to your server" -> :timeout
      text =~ "refusing to let us open a connection" -> :refused
      text =~ "not letting us in with the username" -> :auth_failed
      text =~ "does not match those you have registered" -> :key_exchange
      text =~ "does not meet the expected configuration" -> :property_mismatch
      text =~ "reach some of the ports" -> :open_ports
    end
  end

  defp links_detail(nil), do: nil
  defp links_detail(note), do: %{links: links(note)}

  defp timeout_detail(nil), do: nil

  defp timeout_detail(note) do
    [_whole, port] = Regex.run(~r/connection to port (\d+)/, html_element_text(note))
    %{ssh_port: String.to_integer(port), links: links(note)}
  end

  defp property_mismatch_detail(nil), do: nil

  defp property_mismatch_detail(note) do
    bullets = note |> find_html_elements("li") |> Enum.map(&html_element_text/1)

    %{
      hardware: Enum.any?(bullets, &(&1 =~ "hardware and/or operating system")),
      hostname: Enum.any?(bullets, &(&1 =~ "hostname of your server does not match")),
      swap: Enum.any?(bullets, &(&1 =~ "swap space")),
      links: links(note)
    }
  end

  defp links(note),
    do: note |> find_html_elements("a") |> Enum.map(&html_element_attribute(&1, "href"))

  defp real_time_state(connection_state, opts \\ []),
    do: %ServerRealTimeState{
      connection_state: connection_state,
      name: "srv",
      conn_params: {{127, 0, 0, 1}, 22, "user"},
      username: "user",
      app_username: "app",
      current_job: Keyword.get(opts, :current_job),
      problems: Keyword.get(opts, :problems, []),
      version: 1
    }

  defp timeout_problem, do: {:server_connection_timed_out, {127, 0, 0, 1}, 22, "user"}
  defp refused_problem, do: {:server_connection_refused, {127, 0, 0, 1}, 22, "user"}
  defp auth_problem, do: {:server_authentication_failed, :username, "user"}
  defp key_exchange_problem, do: {:server_key_exchange_failed, nil, "fp"}
  defp open_ports_problem, do: {:server_open_ports_check_failed, [{8080, "timeout"}]}

  defp mismatch_problem(property),
    do: {:server_expected_property_mismatch, property, "exp", "act"}
end
