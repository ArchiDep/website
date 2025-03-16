defmodule ArchiDepWeb.Auth.AuthController do
  use ArchiDepWeb, :controller

  import ArchiDepWeb.Helpers.ConnHelpers
  alias ArchiDep.Accounts
  alias ArchiDepWeb.Auth

  plug Ueberauth

  @spec login(Conn.t(), map) :: Conn.t()
  def login(conn, _params) do
    render(conn, "login.html")
  end

  @spec logout(Conn.t(), map) :: Conn.t()
  def logout(conn, %{}) do
    Auth.log_out(conn)
  end

  @spec configure_switch_edu_id_login(Conn.t(), map) :: Conn.t()
  def configure_switch_edu_id_login(conn, params),
    do:
      conn
      |> put_session(:remember_me, Map.has_key?(params, "remember-me"))
      |> redirect(to: "/auth/switch-edu-id")

  @spec callback(Conn.t(), map) :: Conn.t()

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
    IO.puts("@@@@@@@@@@@@@@@ fails #{inspect(fails)}")

    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/login")
  end

  def callback(
        %{
          assigns: %{
            ueberauth_auth: %Ueberauth.Auth{
              provider: :switch_edu_id,
              extra: %Ueberauth.Auth.Extra{
                raw_info: %{
                  userinfo: %{
                    "email" => email,
                    "given_name" => first_name,
                    "swissEduPersonUniqueID" => swiss_edu_person_unique_id
                  }
                }
              }
            }
          }
        } = conn,
        _params
      ) do
    with {:ok, auth} <-
           Accounts.log_in_or_register_with_switch_edu_id(
             %{
               swiss_edu_person_unique_id: swiss_edu_person_unique_id,
               email: email,
               first_name: first_name,
               last_name: nil
             },
             conn_metadata(conn)
           ) do
      conn
      |> Auth.log_in(auth)
      |> put_flash(:info, "Welcome!")
    else
      {:error, :unauthorized_switch_edu_id} ->
        conn
        |> put_flash(
          :error,
          "Your Switch edu-ID account is not authorized to access this application."
        )
        |> redirect(to: "/app")
    end
  end
end
