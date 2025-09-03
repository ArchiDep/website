defmodule ArchiDepWeb.Auth.AuthController do
  use ArchiDepWeb, :controller

  import ArchiDepWeb.Helpers.ConnHelpers
  alias ArchiDep.Accounts
  alias ArchiDepWeb.Auth
  alias Phoenix.Token
  alias Plug.Conn
  alias Plug.CSRFProtection
  require Logger

  plug Ueberauth

  @spec login(Conn.t(), map) :: Conn.t()
  def login(conn, _params) do
    render(conn, "login.html")
  end

  @spec generate_csrf_token(Conn.t(), map) :: Conn.t()
  def generate_csrf_token(conn, _params) do
    auth = conn.assigns.auth

    if auth == nil do
      send_resp(conn, 401, "")
    else
      token = CSRFProtection.get_csrf_token()
      json(conn, %{token: token})
    end
  end

  @spec generate_socket_token(Conn.t(), map) :: Conn.t()
  def generate_socket_token(conn, _params) do
    auth = conn.assigns.auth

    if auth == nil do
      send_resp(conn, 401, "")
    else
      token = Token.sign(conn, "user socket", auth.session_id, max_age: 300)
      json(conn, %{token: token})
    end
  end

  @spec impersonate(Conn.t(), map) :: Conn.t()
  def impersonate(conn, %{"user_account_id" => user_account_id}) do
    {:ok, impersonated_user_account} = Accounts.impersonate(conn.assigns.auth, user_account_id)
    :ok = Auth.disconnect_session(conn.assigns.auth)

    conn
    |> put_notification(
      Message.new(
        :success,
        gettext("You are impersonating user {user}.", user: impersonated_user_account.username)
      )
    )
    |> redirect(to: ~p"/app")
  end

  @spec stop_impersonating(Conn.t(), map) :: Conn.t()
  def stop_impersonating(conn, %{}) do
    :ok = Accounts.stop_impersonating(conn.assigns.auth)
    :ok = Auth.disconnect_session(conn.assigns.auth)

    conn
    |> put_notification(
      Message.new(:success, gettext("You are no longer impersonating another user."))
    )
    |> redirect(to: ~p"/app")
  end

  @spec logout(Conn.t(), map) :: Conn.t()
  def logout(conn, %{}), do: Auth.log_out(conn)

  @spec configure_switch_edu_id_login(Conn.t(), map) :: Conn.t()
  def configure_switch_edu_id_login(conn, params),
    do:
      conn
      |> put_session(:remember_me, Map.has_key?(params, "remember-me"))
      |> put_session(:user_return_to, Map.get(params, "to"))
      |> redirect(to: "/auth/switch-edu-id")

  @spec callback(Conn.t(), map) :: Conn.t()

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    Logger.warning("Could not authenticate user with Switch edu-ID because #{inspect(failure)}")

    conn
    |> put_notification(
      Message.new(:error, gettext("Failed to authenticate with Switch edu-ID."))
    )
    |> redirect(to: "/login")
  end

  def callback(
        %{
          assigns: %{
            ueberauth_auth: %Ueberauth.Auth{
              provider: :switch_edu_id,
              extra: %Ueberauth.Auth.Extra{
                raw_info: %{
                  userinfo:
                    %{
                      "swissEduPersonUniqueID" => swiss_edu_person_unique_id
                    } = userinfo
                }
              }
            }
          }
        } = conn,
        _params
      ) do
    full_name = switch_edu_id_full_name(userinfo)
    Logger.info("Switch edu-ID login for #{full_name} (#{swiss_edu_person_unique_id})")

    case Accounts.log_in_or_register_with_switch_edu_id(
           %{
             swiss_edu_person_unique_id: swiss_edu_person_unique_id,
             emails: collect_switch_edu_id_emails(userinfo),
             first_name: Map.get(userinfo, "given_name"),
             last_name: Map.get(userinfo, "family_name")
           },
           conn_metadata(conn)
         ) do
      {:ok, auth} ->
        conn
        |> put_notification(Message.new(:success, gettext("Welcome!")))
        |> Auth.log_in(auth)

      {:error, :unauthorized_switch_edu_id} ->
        conn
        |> put_notification(
          Message.new(
            :error,
            gettext("Your Switch edu-ID account is not authorized to access this application.")
          )
        )
        |> redirect(to: "/login")
    end
  end

  defp switch_edu_id_full_name(userinfo) do
    case [Map.get(userinfo, "given_name"), Map.get(userinfo, "family_name")] do
      [nil, nil] -> "<unknown>"
      names -> names |> Enum.filter(&is_binary/1) |> Enum.join(" ")
    end
  end

  defp collect_switch_edu_id_emails(user_info),
    do:
      Enum.reduce(
        [
          switch_edu_id_main_email(user_info)
          | switch_edu_id_affiliation_emails(user_info)
        ],
        MapSet.new(),
        fn
          email, acc when is_binary(email) -> MapSet.put(acc, email)
          _invalid_email, acc -> acc
        end
      )

  defp switch_edu_id_main_email(%{"email" => email}) when is_binary(email), do: email
  defp switch_edu_id_main_email(_userinfo), do: nil

  defp switch_edu_id_affiliation_emails(%{"swissEduIDLinkedAffiliationMail" => emails})
       when is_list(emails),
       do: emails

  defp switch_edu_id_affiliation_emails(_userinfo), do: []
end
