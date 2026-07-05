defmodule ArchiDepWeb.ConfigTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Config.ConfigError
  alias ArchiDepWeb.Config

  @base_endpoint_config [
    http: [ip: {127, 0, 0, 1}, port: 4000],
    live_view: [signing_salt: String.duplicate("a", 20)],
    secret_key_base: String.duplicate("b", 50),
    session_signing_salt: String.duplicate("c", 20),
    url: [scheme: "https", host: "archidep.ch", port: 443, path: "/"]
  ]

  describe "endpoint/2" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      uploads_directory = Path.join(tmp_dir, "uploads")
      File.mkdir!(uploads_directory)

      %{
        config: Keyword.put(@base_endpoint_config, :uploads_directory, uploads_directory),
        uploads_directory: uploads_directory
      }
    end

    test "reads the whole endpoint configuration from the environment", %{
      config: config,
      tmp_dir: tmp_dir
    } do
      env_uploads_directory = Path.join(tmp_dir, "env_uploads")
      File.mkdir!(env_uploads_directory)

      env = %{
        "ARCHIDEP_WEB_ENDPOINT_HTTP_IP" => "192.168.1.1",
        "ARCHIDEP_WEB_ENDPOINT_HTTP_PORT" => "8080",
        "ARCHIDEP_WEB_ENDPOINT_LIVE_VIEW_SIGNING_SALT" => String.duplicate("s", 20),
        "ARCHIDEP_WEB_ENDPOINT_SECRET_KEY_BASE" => String.duplicate("k", 50),
        "ARCHIDEP_WEB_ENDPOINT_SESSION_SIGNING_SALT" => String.duplicate("z", 20),
        "ARCHIDEP_WEB_ENDPOINT_UPLOADS_DIRECTORY" => env_uploads_directory,
        "ARCHIDEP_WEB_ENDPOINT_URL" => "https://example.com/path"
      }

      assert Config.endpoint(env, config) == [
               http: [ip: {192, 168, 1, 1}, port: 8080],
               live_view: [signing_salt: String.duplicate("s", 20)],
               secret_key_base: String.duplicate("k", 50),
               session_signing_salt: String.duplicate("z", 20),
               uploads_directory: env_uploads_directory,
               url: [port: 443, scheme: "https", path: "/path", host: "example.com"]
             ]
    end

    test "falls back to the application configuration when the environment is unset", %{
      config: config,
      uploads_directory: uploads_directory
    } do
      assert Config.endpoint(%{}, config) == [
               http: [ip: {127, 0, 0, 1}, port: 4000],
               live_view: [signing_salt: String.duplicate("a", 20)],
               secret_key_base: String.duplicate("b", 50),
               session_signing_salt: String.duplicate("c", 20),
               uploads_directory: uploads_directory,
               url: [scheme: "https", host: "archidep.ch", port: 443, path: "/"]
             ]
    end

    test "parses an IPv6 bind address from the environment", %{
      config: config,
      uploads_directory: uploads_directory
    } do
      assert Config.endpoint(%{"ARCHIDEP_WEB_ENDPOINT_HTTP_IP" => "::1"}, config) == [
               http: [ip: {0, 0, 0, 0, 0, 0, 0, 1}, port: 4000],
               live_view: [signing_salt: String.duplicate("a", 20)],
               secret_key_base: String.duplicate("b", 50),
               session_signing_salt: String.duplicate("c", 20),
               uploads_directory: uploads_directory,
               url: [scheme: "https", host: "archidep.ch", port: 443, path: "/"]
             ]
    end

    test "raises when the bind address from the environment is not an IP address", %{
      config: config
    } do
      assert_raise ConfigError,
                   "Endpoint HTTP bind IP \"999.1.1.1\" is invalid.\n" <>
                     "This value was set in environment variable $ARCHIDEP_WEB_ENDPOINT_HTTP_IP.",
                   fn ->
                     Config.endpoint(%{"ARCHIDEP_WEB_ENDPOINT_HTTP_IP" => "999.1.1.1"}, config)
                   end
    end

    test "raises when the configured bind address is not a valid IP tuple", %{config: config} do
      assert_raise ConfigError,
                   "Endpoint HTTP bind IP {999, 1, 1, 1} is invalid.\n" <>
                     "This value was set in one of the \"config/*.exs\" files.",
                   fn -> Config.endpoint(%{}, put_in(config, [:http, :ip], {999, 1, 1, 1})) end
    end

    test "raises when the port from the environment is not an integer", %{config: config} do
      assert_raise ConfigError,
                   "Endpoint HTTP port \"abc\" is invalid.\n" <>
                     "This value was set in environment variable $ARCHIDEP_WEB_ENDPOINT_HTTP_PORT.",
                   fn ->
                     Config.endpoint(%{"ARCHIDEP_WEB_ENDPOINT_HTTP_PORT" => "abc"}, config)
                   end
    end

    test "raises when the port is out of the 1..65535 range", %{config: config} do
      for raw <- ["0", "70000"] do
        assert_raise ConfigError,
                     "Endpoint HTTP port #{inspect(raw)} is invalid.\n" <>
                       "This value was set in environment variable $ARCHIDEP_WEB_ENDPOINT_HTTP_PORT.",
                     fn ->
                       Config.endpoint(%{"ARCHIDEP_WEB_ENDPOINT_HTTP_PORT" => raw}, config)
                     end
      end
    end

    test "raises when a signing salt is shorter than 20 bytes", %{config: config} do
      for {key, description} <- [
            {:live_view, "Endpoint live view signing salt"},
            {:session_signing_salt, "Endpoint session signing salt"}
          ] do
        bad_config =
          case key do
            :live_view -> put_in(config, [:live_view, :signing_salt], "short")
            :session_signing_salt -> Keyword.put(config, key, "short")
          end

        assert_raise ConfigError,
                     "#{description} \"short\" is invalid.\n" <>
                       "It must be a random string at least 20 bytes long.\n" <>
                       "You can generate one by calling \"mix phx.gen.secret\".\n" <>
                       "This value was set in one of the \"config/*.exs\" files.",
                     fn -> Config.endpoint(%{}, bad_config) end
      end
    end

    test "raises when the secret key base is shorter than 50 bytes", %{config: config} do
      assert_raise ConfigError,
                   "Endpoint secret key base \"short\" is invalid.\n" <>
                     "It must be a random string at least 50 bytes long.\n" <>
                     "You can generate one by calling \"mix phx.gen.secret\".\n" <>
                     "This value was set in one of the \"config/*.exs\" files.",
                   fn -> Config.endpoint(%{}, Keyword.put(config, :secret_key_base, "short")) end
    end

    test "accepts a configured URL with a string or absent port", %{
      config: config,
      uploads_directory: uploads_directory
    } do
      for url <- [
            [scheme: "https", host: "archidep.ch", port: "8080", path: "/"],
            [scheme: "http", host: "localhost", path: "/"]
          ] do
        assert Config.endpoint(%{}, Keyword.put(config, :url, url)) == [
                 http: [ip: {127, 0, 0, 1}, port: 4000],
                 live_view: [signing_salt: String.duplicate("a", 20)],
                 secret_key_base: String.duplicate("b", 50),
                 session_signing_salt: String.duplicate("c", 20),
                 uploads_directory: uploads_directory,
                 url: url
               ]
      end
    end

    test "raises when the URL from the environment is not an http(s) URL", %{config: config} do
      assert_raise ConfigError,
                   "Endpoint URL \"ftp://example.com/path\" is invalid.\n" <>
                     "It must be an HTTP(S) URL with scheme, host, port and path components, for example:\n\n" <>
                     "    https://example.com/path\n" <>
                     "This value was set in environment variable $ARCHIDEP_WEB_ENDPOINT_URL.",
                   fn ->
                     Config.endpoint(
                       %{"ARCHIDEP_WEB_ENDPOINT_URL" => "ftp://example.com/path"},
                       config
                     )
                   end
    end

    test "raises when the configured URL is malformed", %{config: config} do
      bad_urls = [
        [scheme: "ftp", host: "archidep.ch", port: 443, path: "/"],
        [scheme: "https", host: "archidep.ch", port: 443, path: "/", extra: "nope"],
        [scheme: "https", host: "archidep.ch", port: 70_000, path: "/"],
        [scheme: "https", host: "archidep.ch", port: "abc", path: "/"]
      ]

      for bad_url <- bad_urls do
        assert_raise ConfigError,
                     "Endpoint URL #{inspect(bad_url)} is invalid.\n" <>
                       "It must be an HTTP(S) URL with scheme, host, port and path components, for example:\n\n" <>
                       "    https://example.com/path\n" <>
                       "This value was set in one of the \"config/*.exs\" files.",
                     fn -> Config.endpoint(%{}, Keyword.put(config, :url, bad_url)) end
      end
    end

    test "raises when a required endpoint value is missing", %{config: config} do
      salt_format =
        "It must be a random string at least 20 bytes long.\n" <>
          "You can generate one by calling \"mix phx.gen.secret\"."

      missing = [
        {[:http, :ip], "Endpoint HTTP bind IP", "ARCHIDEP_WEB_ENDPOINT_HTTP_IP", nil},
        {[:http, :port], "Endpoint HTTP port", "ARCHIDEP_WEB_ENDPOINT_HTTP_PORT", nil},
        {[:live_view, :signing_salt], "Endpoint live view signing salt",
         "ARCHIDEP_WEB_ENDPOINT_LIVE_VIEW_SIGNING_SALT", salt_format},
        {[:secret_key_base], "Endpoint secret key base", "ARCHIDEP_WEB_ENDPOINT_SECRET_KEY_BASE",
         "It must be a random string at least 50 bytes long.\n" <>
           "You can generate one by calling \"mix phx.gen.secret\"."},
        {[:session_signing_salt], "Endpoint session signing salt",
         "ARCHIDEP_WEB_ENDPOINT_SESSION_SIGNING_SALT", salt_format},
        {[:uploads_directory], "Endpoint uploads directory",
         "ARCHIDEP_WEB_ENDPOINT_UPLOADS_DIRECTORY",
         "It must be the path to a writable directory, for example:\n\n    /var/lib/app/uploads"},
        {[:url], "Endpoint URL", "ARCHIDEP_WEB_ENDPOINT_URL",
         "It must be an HTTP(S) URL with scheme, host, port and path components, for example:\n\n" <>
           "    https://example.com/path"}
      ]

      for {path, description, env_var, format} <- missing do
        assert_raise ConfigError,
                     required_message(description, env_var, format),
                     fn -> Config.endpoint(%{}, put_in(config, path, nil)) end
      end
    end

    test "rejects an uploads directory that is invalid, explaining why", %{
      config: config,
      tmp_dir: tmp_dir
    } do
      read_only = Path.join(tmp_dir, "read_only")
      File.mkdir!(read_only)
      File.chmod!(read_only, 0o500)

      not_a_directory = Path.join(tmp_dir, "file")
      File.write!(not_a_directory, "not a dir")

      missing = Path.join(tmp_dir, "missing")

      cases = [
        {read_only, "the directory is not writable"},
        {not_a_directory, "the path is not a directory"},
        {missing, "the directory could not be read (no such file or directory)"}
      ]

      for {path, reason} <- cases do
        assert_raise ConfigError,
                     "Endpoint uploads directory #{inspect(path)} is invalid: #{reason}\n" <>
                       "It must be the path to a writable directory, for example:\n\n" <>
                       "    /var/lib/app/uploads\n" <>
                       "This value was set in one of the \"config/*.exs\" files.",
                     fn -> Config.endpoint(%{}, Keyword.put(config, :uploads_directory, path)) end
      end
    end
  end

  describe "switch_edu_id_issuer/2" do
    test "reads the issuer URL from the environment" do
      env = %{"ARCHIDEP_AUTH_SWITCH_EDU_ID_ISSUER_URL" => "https://issuer.example.com"}

      assert Config.switch_edu_id_issuer(env, %{issuer: "https://ignored.example.com"}) == %{
               name: :switch_edu_id,
               issuer: "https://issuer.example.com"
             }
    end

    test "falls back to the application configuration when the environment is unset" do
      assert Config.switch_edu_id_issuer(%{}, %{issuer: "https://issuer.example.com"}) == %{
               name: :switch_edu_id,
               issuer: "https://issuer.example.com"
             }
    end

    test "raises when the issuer URL is neither in the environment nor the configuration" do
      assert_raise ConfigError,
                   required_message(
                     "Switch edu-ID OpenID Connect issuer URL",
                     "ARCHIDEP_AUTH_SWITCH_EDU_ID_ISSUER_URL"
                   ),
                   fn -> Config.switch_edu_id_issuer(%{}, %{}) end
    end
  end

  describe "switch_edu_id_auth_credentials/2" do
    test "reads the credentials from the environment" do
      env = %{
        "ARCHIDEP_AUTH_SWITCH_EDU_ID_CLIENT_ID" => "client-id",
        "ARCHIDEP_AUTH_SWITCH_EDU_ID_CLIENT_SECRET" => "client-secret"
      }

      default_config = [switch_edu_id: [client_id: "ignored", client_secret: "ignored"]]

      assert Config.switch_edu_id_auth_credentials(env, default_config) == [
               client_id: "client-id",
               client_secret: "client-secret"
             ]
    end

    test "falls back to the application configuration when the environment is unset" do
      default_config = [switch_edu_id: [client_id: "client-id", client_secret: "client-secret"]]

      assert Config.switch_edu_id_auth_credentials(%{}, default_config) == [
               client_id: "client-id",
               client_secret: "client-secret"
             ]
    end

    test "raises when the client ID is missing" do
      default_config = [switch_edu_id: [client_id: nil, client_secret: "client-secret"]]

      assert_raise ConfigError,
                   required_message(
                     "Switch edu-ID client ID for OpenID Connect authentication",
                     "ARCHIDEP_AUTH_SWITCH_EDU_ID_CLIENT_ID"
                   ),
                   fn -> Config.switch_edu_id_auth_credentials(%{}, default_config) end
    end

    test "raises when the client secret is missing" do
      default_config = [switch_edu_id: [client_id: "client-id", client_secret: nil]]

      assert_raise ConfigError,
                   required_message(
                     "Switch edu-ID client secret for OpenID Connect authentication",
                     "ARCHIDEP_AUTH_SWITCH_EDU_ID_CLIENT_SECRET"
                   ),
                   fn -> Config.switch_edu_id_auth_credentials(%{}, default_config) end
    end
  end

  defp required_message(description, env_var, format \\ nil) do
    [
      "#{description} is required but was not provided.",
      format,
      "",
      "Set it with environment variable $#{env_var}.\n" <>
        "Or set it with one of the \"config/*.exs\" files."
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end
end
