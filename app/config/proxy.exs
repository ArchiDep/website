import Config

config_dir = Path.dirname(__ENV__.file)
import_config Path.join(config_dir, "dev.exs")

config :archidep, ArchiDepWeb.Endpoint,
  url: [scheme: "https", host: "test.archidep.ch", port: 443]
