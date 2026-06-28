defmodule ArchiDepWeb.Auth.AuthControllerTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import ArchiDep.Support.TokenTestHelpers
  import ArchiDepWeb.Support.HtmlTestHelpers
  import Hammox
  alias ArchiDep.Accounts
  alias ArchiDep.ClientMetadata
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.Factory
  alias ArchiDepWeb.Auth.AuthController
  alias ArchiDepWeb.Endpoint
  alias Phoenix.Token

  @remember_me_cookie "_archidep_remember_me"
  @remember_me_max_age 60 * 60 * 24 * 60
  @user_agent "ExUnit/1.0"
  @metadata ClientMetadata.new({127, 0, 0, 1}, @user_agent)

  setup :verify_on_exit!

  describe "GET /login" do
    test "render the login page for an anonymous user", %{conn: conn} do
      conn = get(conn, ~p"/login")

      assert login_form(html_response(conn, 200)) == %{
               action: "/auth/switch-edu-id/configure",
               method: "get",
               submit: "Log in",
               remember_me_checkboxes: 1
             }
    end

    test "redirect an authenticated user to the application", context do
      %{conn: conn} = register_and_log_in_root(context)

      assert conn |> get(~p"/login") |> redirected_to() == ~p"/app"
    end
  end

  describe "GET /auth/switch-edu-id/configure" do
    test "store the remember-me flag and return path, then start the login flow", %{conn: conn} do
      conn =
        get(conn, ~p"/auth/switch-edu-id/configure?#{[{"remember-me", "true"}, {"to", "/app"}]}")

      assert auth_result(conn) == %{
               redirected_to: "/auth/switch-edu-id",
               session: %{"remember_me" => true, "user_return_to" => "/app"},
               flash: [],
               remember_me_cookie: :absent
             }
    end

    test "default the remember-me flag and return path when absent", %{conn: conn} do
      conn = get(conn, ~p"/auth/switch-edu-id/configure")

      assert auth_result(conn) == %{
               redirected_to: "/auth/switch-edu-id",
               session: %{"remember_me" => false, "user_return_to" => nil},
               flash: [],
               remember_me_cookie: :absent
             }
    end
  end

  describe "GET /auth/link" do
    test "log a user in from a valid login link", %{conn: conn} do
      raw_token = "raw-login-link-token"
      auth = Factory.build(:authentication)

      expect(Accounts.ContextMock, :log_in_or_register_with_link, 1, fn ^raw_token, @metadata ->
        {:ok, auth}
      end)

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> get(~p"/auth/link?#{[token: Base.encode64(raw_token)]}")

      assert auth_result(conn) == %{
               redirected_to: ~p"/app",
               session: logged_in_session(auth),
               flash: [{:success, "Welcome!"}],
               remember_me_cookie: :absent
             }
    end

    test "honor the stored return path and remember-me flag when logging in", %{conn: conn} do
      raw_token = "raw-login-link-token"
      auth = Factory.build(:authentication)

      expect(Accounts.ContextMock, :log_in_or_register_with_link, 1, fn ^raw_token, @metadata ->
        {:ok, auth}
      end)

      conn =
        conn
        |> init_test_session(%{remember_me: true, user_return_to: "/app/my-servers"})
        |> put_req_header("user-agent", @user_agent)
        |> get(~p"/auth/link?#{[token: Base.encode64(raw_token)]}")

      assert auth_result(conn) == %{
               redirected_to: "/app/my-servers",
               session: logged_in_session(auth),
               flash: [{:success, "Welcome!"}],
               remember_me_cookie: %{
                 value?: true,
                 max_age: @remember_me_max_age,
                 same_site: "Lax"
               }
             }
    end

    test "reject a malformed login link token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> get(~p"/auth/link?#{[token: "%%% not base64 %%%"]}")

      assert auth_result(conn) == %{
               redirected_to: "/login",
               session: %{},
               flash: [{:error, "This login link has expired or is invalid."}],
               remember_me_cookie: :absent
             }
    end

    test "reject an invalid login link", %{conn: conn} do
      raw_token = "raw-login-link-token"

      expect(Accounts.ContextMock, :log_in_or_register_with_link, 1, fn ^raw_token, @metadata ->
        {:error, :invalid_link}
      end)

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> get(~p"/auth/link?#{[token: Base.encode64(raw_token)]}")

      assert auth_result(conn) == %{
               redirected_to: "/login",
               session: %{},
               flash: [{:error, "This login link has expired or is invalid."}],
               remember_me_cookie: :absent
             }
    end
  end

  # The Switch edu-ID callback sits behind the third-party `plug Ueberauth`, and
  # the test issuer is the real `login.test.eduid.ch`, so dispatching through the
  # router would trigger OpenID Connect discovery over the network. These tests
  # invoke the action directly with the `ueberauth_auth`/`ueberauth_failure`
  # assign the plug would have produced.
  describe "GET /auth/switch-edu-id/callback" do
    test "log a user in from a successful Switch edu-ID authentication" do
      auth = Factory.build(:authentication)

      expected_login = %{
        swiss_edu_person_unique_id: "person-123",
        emails: ["main@example.com", "aff1@example.com", "aff2@example.com"],
        first_name: "Alice",
        last_name: "Cidre"
      }

      expect(Accounts.ContextMock, :log_in_or_register_with_switch_edu_id, 1, fn ^expected_login,
                                                                                 @metadata ->
        {:ok, auth}
      end)

      conn =
        [
          ueberauth_auth:
            switch_edu_id_auth(%{
              "swissEduPersonUniqueID" => "person-123",
              "given_name" => "Alice",
              "family_name" => "Cidre",
              "email" => "main@example.com",
              "swissEduIDLinkedAffiliationMail" => ["aff1@example.com", "aff2@example.com"]
            })
        ]
        |> callback_conn()
        |> AuthController.callback(%{})

      assert auth_result(conn) == %{
               redirected_to: ~p"/app",
               session: logged_in_session(auth),
               flash: [{:success, "Welcome!"}],
               remember_me_cookie: :absent
             }
    end

    test "reject an unauthorized Switch edu-ID account" do
      expected_login = %{
        swiss_edu_person_unique_id: "person-123",
        emails: ["main@example.com"],
        first_name: nil,
        last_name: nil
      }

      expect(Accounts.ContextMock, :log_in_or_register_with_switch_edu_id, 1, fn ^expected_login,
                                                                                 @metadata ->
        {:error, :unauthorized_switch_edu_id}
      end)

      conn =
        [
          ueberauth_auth:
            switch_edu_id_auth(%{
              "swissEduPersonUniqueID" => "person-123",
              "email" => "main@example.com"
            })
        ]
        |> callback_conn()
        |> AuthController.callback(%{})

      assert auth_result(conn) == %{
               redirected_to: "/login",
               session: %{},
               flash: [
                 {:error,
                  "Your Switch edu-ID account is not authorized to access this application."}
               ],
               remember_me_cookie: :absent
             }
    end

    @tag capture_log: true
    test "report a failed Switch edu-ID authentication" do
      conn =
        [
          ueberauth_failure: %Ueberauth.Failure{
            provider: :switch_edu_id,
            strategy: Ueberauth.Strategy.Oidcc
          }
        ]
        |> callback_conn()
        |> AuthController.callback(%{})

      assert auth_result(conn) == %{
               redirected_to: "/login",
               session: %{},
               flash: [{:error, "Failed to authenticate with Switch edu-ID."}],
               remember_me_cookie: :absent
             }
    end
  end

  describe "GET /auth/csrf" do
    test "return a CSRF token for a root user", context do
      %{conn: conn} = register_and_log_in_root(context)

      assert_csrf_token(conn)
    end

    test "return a CSRF token for a student", context do
      %{conn: conn} = register_and_log_in_student(context)

      assert_csrf_token(conn)
    end

    test "reject an anonymous user", %{conn: conn} do
      conn = get(conn, ~p"/auth/csrf")

      assert response(conn, 401) == ""
    end
  end

  describe "GET /auth/socket" do
    test "return a verifiable socket token for a root user", context do
      %{conn: conn, auth: auth} = register_and_log_in_root(context)

      assert_socket_token(conn, auth)
    end

    test "return a verifiable socket token for a student", context do
      %{conn: conn, auth: auth} = register_and_log_in_student(context)

      assert_socket_token(conn, auth)
    end

    test "reject an anonymous user", %{conn: conn} do
      conn = get(conn, ~p"/auth/socket")

      assert response(conn, 401) == ""
    end
  end

  describe "POST /auth/impersonate" do
    setup :register_and_log_in_root

    test "impersonate a user identified by their preregistered name", %{conn: conn, auth: auth} do
      preregistered_user = AccountsFactory.build(:preregistered_user, name: "Jane Doe")
      impersonated = AccountsFactory.build(:user_account, preregistered_user: preregistered_user)
      impersonated_id = impersonated.id

      expect(Accounts.ContextMock, :impersonate, 1, fn ^auth, ^impersonated_id ->
        {:ok, impersonated}
      end)

      topic = disconnect_topic(auth)
      :ok = Endpoint.subscribe(topic)

      conn =
        conn
        |> bypass_csrf()
        |> post(~p"/auth/impersonate", %{"user_account_id" => impersonated_id})

      assert auth_result(conn) == %{
               redirected_to: ~p"/app",
               session: logged_in_session(auth),
               flash: [{:success, "You are impersonating user Jane Doe."}],
               remember_me_cookie: :absent
             }

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "disconnect", payload: %{}}
    end

    test "impersonate a user identified by their username when not preregistered", %{
      conn: conn,
      auth: auth
    } do
      impersonated =
        AccountsFactory.build(:user_account, username: "rootlike", preregistered_user: nil)

      impersonated_id = impersonated.id

      expect(Accounts.ContextMock, :impersonate, 1, fn ^auth, ^impersonated_id ->
        {:ok, impersonated}
      end)

      conn =
        conn
        |> bypass_csrf()
        |> post(~p"/auth/impersonate", %{"user_account_id" => impersonated_id})

      assert auth_result(conn) == %{
               redirected_to: ~p"/app",
               session: logged_in_session(auth),
               flash: [{:success, "You are impersonating user rootlike."}],
               remember_me_cookie: :absent
             }
    end
  end

  describe "POST /auth/stop-impersonating" do
    setup :register_and_log_in_root

    test "stop impersonating another user", %{conn: conn, auth: auth} do
      expect(Accounts.ContextMock, :stop_impersonating, 1, fn ^auth -> :ok end)

      topic = disconnect_topic(auth)
      :ok = Endpoint.subscribe(topic)

      conn =
        conn
        |> bypass_csrf()
        |> post(~p"/auth/stop-impersonating")

      assert auth_result(conn) == %{
               redirected_to: ~p"/app",
               session: logged_in_session(auth),
               flash: [{:success, "You are no longer impersonating another user."}],
               remember_me_cookie: :absent
             }

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "disconnect", payload: %{}}
    end
  end

  describe "DELETE /logout" do
    test "log an authenticated user out", context do
      %{conn: conn, auth: auth} = register_and_log_in_root(context)

      expect(Accounts.ContextMock, :log_out, 1, fn ^auth -> :ok end)

      topic = disconnect_topic(auth)
      :ok = Endpoint.subscribe(topic)

      logged_out = conn |> bypass_csrf() |> delete(~p"/logout")

      assert auth_result(logged_out) == %{
               redirected_to: "/login",
               session: %{},
               flash: [],
               remember_me_cookie: :deleted
             }

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "disconnect", payload: %{}}
    end

    test "clear the session for an anonymous user without calling the context", %{conn: conn} do
      conn = conn |> bypass_csrf() |> delete(~p"/logout")

      assert auth_result(conn) == %{
               redirected_to: "/login",
               session: %{},
               flash: [],
               remember_me_cookie: :deleted
             }
    end
  end

  defp assert_csrf_token(conn) do
    response = conn |> get(~p"/auth/csrf") |> json_response(200)

    assert Map.keys(response) == ["token"]
    assert_secure_random_token(response["token"])
  end

  defp assert_socket_token(conn, auth) do
    response = conn |> get(~p"/auth/socket") |> json_response(200)

    assert Map.keys(response) == ["token"]

    assert Token.verify(@endpoint, "user socket", response["token"], max_age: 300) ==
             {:ok, auth.session_id}
  end

  defp login_form(html) do
    form = html |> find_html_elements("form") |> hd()

    %{
      action: html_element_attribute(form, "action"),
      method: html_element_attribute(form, "method"),
      submit:
        form |> find_html_elements(~s(button[type="submit"])) |> hd() |> html_element_text(),
      remember_me_checkboxes:
        form |> find_html_elements(~s(input[type="checkbox"][name="remember-me"])) |> length()
    }
  end

  defp switch_edu_id_auth(userinfo),
    do: %Ueberauth.Auth{
      provider: :switch_edu_id,
      extra: %Ueberauth.Auth.Extra{raw_info: %{userinfo: userinfo}}
    }

  defp callback_conn(assigns) do
    conn =
      build_conn()
      |> init_test_session(%{})
      |> put_req_header("user-agent", @user_agent)
      |> Phoenix.Controller.fetch_flash([])

    Enum.reduce(assigns, conn, fn {key, value}, acc -> assign(acc, key, value) end)
  end

  # `Plug.CSRFProtection`'s documented test escape hatch, needed because the
  # mutation routes go through the browser pipeline's `protect_from_forgery`.
  defp bypass_csrf(conn), do: Conn.put_private(conn, :plug_skip_csrf_protection, true)

  defp disconnect_topic(auth), do: "auth:#{auth.principal_id}"

  # A whole-response projection of every output an auth action controls: the
  # redirect target, the resulting session (minus the flash Phoenix persists into
  # it, projected separately), the flash notifications by `{type, message}`, and
  # the remember-me cookie state. Asserting it by equality pins presence and
  # absence at once.
  defp auth_result(conn),
    do: %{
      redirected_to: redirected_to(conn),
      session: conn |> get_session() |> Map.drop(["phoenix_flash"]),
      flash: flash_notifications(conn),
      remember_me_cookie: remember_me_cookie(conn)
    }

  defp logged_in_session(auth),
    do: %{"session_token" => auth.session_token, "live_socket_id" => "auth:" <> auth.principal_id}

  defp flash_notifications(conn),
    do:
      conn.assigns
      |> Map.get(:flash, %{})
      |> Map.values()
      |> Enum.map(fn notification -> {notification.type, notification.message} end)

  defp remember_me_cookie(conn) do
    case Map.get(conn.resp_cookies, @remember_me_cookie) do
      nil ->
        :absent

      %{max_age: 0} ->
        :deleted

      cookie ->
        %{
          value?: is_binary(cookie.value) and cookie.value != "",
          max_age: cookie.max_age,
          same_site: cookie.same_site
        }
    end
  end
end
