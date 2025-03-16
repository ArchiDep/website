defmodule ArchiDepWeb.Auth.AuthController do
  use ArchiDepWeb, :controller

  import ArchiDepWeb.Helpers.ConnHelpers
  alias ArchiDep.Accounts
  alias ArchiDepWeb.Auth

  plug Ueberauth

  def login(conn, _params) do
    render(conn, "login.html")
  end

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
        params
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
      |> Auth.log_in(auth, params)
      |> put_flash(:info, "Welcome!")
      |> redirect(to: "/app")
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
