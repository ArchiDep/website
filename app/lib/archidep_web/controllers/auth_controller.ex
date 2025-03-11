defmodule ArchiDepWeb.AuthController do
  use ArchiDepWeb, :controller

  plug Ueberauth

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
    IO.puts "@@@@@@@@@@@@@@@ fails #{inspect(fails)}"
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/app")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    IO.puts "@@@@@@@@@@@@@@@@ #{inspect(auth)}"
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
