import Config

if config_env() != :test do
  config :archidep,
    # Generate your own key pair using `ssh-keygen -t ed25519 -C "archidep"`
    public_key:
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxsZfyuRVJsWGYbLaZLTCDahyT9QhnT1ixz5ghIL0FB archidep",
    # Emails which will create root user accounts when logging in
    root_users: ["example@archidep.ch"]
end

# Database connection
config :archidep, ArchiDep.Repo,
  url:
    if(config_env() != :test,
      # dev
      do: "ecto://archidep@localhost/archidep",
      # test
      else: "ecto://archidep@localhost/archidep-test#{System.get_env("MIX_TEST_PARTITION")}"
    )

# Web endpoint configuration
# Generate appropriate secrets and salts with `mix phx.gen.secret`.
config :archidep, ArchiDepWeb.Endpoint,
  live_view: [
    signing_salt: "changeme"
  ],
  secret_key_base: "changeme",
  session_signing_salt: "changeme"

# Ueberauth configuration for Switch Edu ID
config :ueberauth_oidcc, :providers,
  switch_edu_id: [client_id: "changeme", client_secret: "changeme"]
