defmodule ArchiDepWeb.Channels.UserSocketTest do
  use ArchiDepWeb.Support.ChannelCase, async: true

  import Phoenix.ConnTest, only: [build_conn: 0]
  alias ArchiDep.Accounts
  alias ArchiDep.ClientMetadata
  alias ArchiDep.Support.Factory

  @moduletag capture_log: true

  @client_ip {192, 168, 1, 23}
  @client_user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/43.4"
  @connect_info %{peer_data: %{address: @client_ip}, user_agent: @client_user_agent}

  describe "connect/3" do
    test "authenticates a valid token against the matching active session" do
      auth = Factory.build(:authentication)
      session_id = auth.session_id
      metadata = ClientMetadata.new(@client_ip, @client_user_agent)

      expect(Accounts.ContextMock, :validate_session_id, 1, fn ^session_id, ^metadata ->
        {:ok, auth}
      end)

      token = sign_user_socket_token(session_id)

      assert {:ok, socket} =
               connect(UserSocket, %{"token" => token}, connect_info: @connect_info)

      assert socket.assigns == %{auth: auth}
    end

    test "refuses to connect without a token" do
      assert connect(UserSocket, %{}, connect_info: @connect_info) == {:error, :missing_token}
    end

    test "refuses a token that is not a string" do
      assert connect(UserSocket, %{"token" => 42}, connect_info: @connect_info) ==
               {:error, :invalid_token_type}
    end

    test "refuses a token the endpoint cannot verify" do
      assert connect(UserSocket, %{"token" => "not-a-valid-token"}, connect_info: @connect_info) ==
               {:error, :unauthorized}
    end

    test "refuses an expired token" do
      expired_at = System.os_time(:second) - 301
      token = sign_user_socket_token(UUID.generate(), signed_at: expired_at)

      assert connect(UserSocket, %{"token" => token}, connect_info: @connect_info) ==
               {:error, :unauthorized}
    end

    test "refuses a valid token whose session no longer exists" do
      session_id = UUID.generate()
      metadata = ClientMetadata.new(@client_ip, @client_user_agent)

      expect(Accounts.ContextMock, :validate_session_id, 1, fn ^session_id, ^metadata ->
        {:error, :session_not_found}
      end)

      token = sign_user_socket_token(session_id)

      assert connect(UserSocket, %{"token" => token}, connect_info: @connect_info) ==
               {:error, :unauthorized}
    end
  end

  describe "id/1" do
    test "identifies the socket by the authenticated principal" do
      auth = Factory.build(:authentication)
      socket = socket(UserSocket, nil, %{auth: auth})

      assert UserSocket.id(socket) == "auth:#{auth.principal_id}"
    end
  end

  describe "handle_error/2" do
    test "renders a connection error as the matching HTTP response" do
      invalid_token_type = UserSocket.handle_error(build_conn(), {:error, :invalid_token_type})
      missing_token = UserSocket.handle_error(build_conn(), {:error, :missing_token})
      unauthorized = UserSocket.handle_error(build_conn(), {:error, :unauthorized})

      assert error_response(invalid_token_type) == {422, ""}
      assert error_response(missing_token) == {422, ""}
      assert error_response(unauthorized) == {401, ""}
    end
  end

  defp error_response(conn), do: {conn.status, conn.resp_body}
end
