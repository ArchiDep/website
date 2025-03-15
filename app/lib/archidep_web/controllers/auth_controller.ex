defmodule ArchiDepWeb.AuthController do
  use ArchiDepWeb, :controller

  import ArchiDepWeb.Helpers.ConnHelpers
  alias ArchiDep.Accounts
  alias Ueberauth.Auth
  alias Ueberauth.Auth.Extra

  plug Ueberauth

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
    IO.puts("@@@@@@@@@@@@@@@ fails #{inspect(fails)}")

    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/app")
  end

  def callback(
        %{
          assigns: %{
            ueberauth_auth: %Auth{
              provider: :switch_edu_id,
              extra: %Extra{
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
    with {:ok, _auth} <-
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
      |> put_flash(:info, "Welcome, ${first_name}!")
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

    # case UserFromAuth.find_or_create(auth) do
    #   {:ok, user} ->
    #     conn
    #     |> put_flash(:info, "Successfully authenticated.")
    #     |> put_session(:current_user, user)
    #     |> configure_session(renew: true)
    #     |> redirect(to: "/")

    #   {:error, reason} ->
    conn
    |> put_flash(:error, "Oops")
    |> redirect(to: "/app")

    # end
  end
end
