import Config

config :archidep, root_users: ["example@archidep.ch"]

config :archidep, ArchiDep.Repo,
  url:
    if(config_env() != :test,
      do: "ecto://archidep@localhost/archidep",
      else: "ecto://archidep@localhost/archidep-test#{System.get_env("MIX_TEST_PARTITION")}"
    )

config :archidep, ArchiDepWeb.Endpoint,
  live_view: [
    signing_salt: "changeme"
  ],
  secret_key_base: "changeme",
  session_signing_salt: "changeme"

config :ueberauth_oidcc, :providers,
  switch_edu_id: [client_id: "changeme", client_secret: "changeme"]
