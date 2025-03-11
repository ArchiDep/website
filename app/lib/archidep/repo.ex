defmodule ArchiDep.Repo do
  use Ecto.Repo,
    otp_app: :archidep,
    adapter: Ecto.Adapters.Postgres
end
