import Config

# config/runtime.exs is executed for all environments, including during
# releases. It is executed after compilation and before the system starts, so it
# is typically used to load production configuration and secrets from
# environment variables or elsewhere. Do not define any compile-time
# configuration in here, as it won't be applied. The block below contains prod
# specific runtime configuration.

config :archidep, ArchiDep.Repo, ArchiDep.Config.repo()
config :archidep, ArchiDepWeb.Endpoint, ArchiDepWeb.Config.endpoint()
config :ueberauth_oidcc, :providers, "switch-edu-id": ArchiDepWeb.Config.switch_edu_id_auth_credentials()

# ## Configuring the mailer
#
# In production you need to configure the mailer to use a different adapter.
# Also, you may need to configure the Swoosh API client of your choice if you
# are not using SMTP. Here is an example of the configuration:
#
#     config :archidep, ArchiDep.Mailer,
#       adapter: Swoosh.Adapters.Mailgun,
#       api_key: System.get_env("MAILGUN_API_KEY"),
#       domain: System.get_env("MAILGUN_DOMAIN")
#
# For this example you need include a HTTP client required by Swoosh API client.
# Swoosh supports Hackney and Finch out of the box:
#
#     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
#
# See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
