defmodule ArchiDepWeb.Config do
  @moduledoc """
  This module retrieves configuration values for the web application from the
  environment and the application configuration, applying appropriate precedence
  rules: values from environment variables always take precedence over
  application values.
  """

  alias ArchiDep.Config.ConfigValue
  alias ArchiDepWeb.Endpoint
  require Logger

  @doc """
  Validates and logs the current configuration of the web application.
  """
  @spec start!() :: :ok
  def start! do
    endpoint_config = Application.fetch_env!(:archidep, Endpoint)
    uploads_directory = endpoint_config[:uploads_directory]
    {:ok, ^uploads_directory} = validate_uploads_directory(uploads_directory)

    ueberauth_oidcc_providers = Application.fetch_env!(:ueberauth_oidcc, :providers)

    Logger.info(~s"""
    Web configuration
    /
    |-> Endpoint
    |   |-> Bind: #{endpoint_config[:http][:ip] |> :inet.ntoa() |> to_string()}
    |   |-> Port: #{inspect(endpoint_config[:http][:port])}
    |   |-> Uploads directory: #{inspect(uploads_directory)}
    |   \\-> URL: #{inspect(endpoint_config[:url])}
    \\-> Ueberauth OpenID Connect
        \\-> Switch edu-ID
            \\-> Client ID: #{inspect(ueberauth_oidcc_providers[:switch_edu_id][:client_id])}
    """)

    :ok
  end

  @doc """
  Read the web endpoint's dynamic configuration.
  """
  @spec endpoint(%{String.t() => String.t()}, Keyword.t()) :: Keyword.t()
  def endpoint(
        env \\ System.get_env(),
        default_config \\ Application.fetch_env!(:archidep, Endpoint)
      ) do
    opts = [
      http: endpoint_http(env, default_config),
      live_view: endpoint_live_view(env, default_config),
      secret_key_base: endpoint_secret_key_base(env, default_config),
      session_signing_salt: endpoint_session_signing_salt(env, default_config),
      uploads_directory: endpoint_uploads_directory(env, default_config),
      url: endpoint_url(env, default_config)
    ]

    Keyword.reject(opts, fn {_key, value} -> is_nil(value) end)
  end

  @doc """
  Read the dynamic configuration for the Switch edu-ID authentication issuer.
  """
  @spec switch_edu_id_issuer(%{String.t() => String.t()}) :: Map.t()
  @spec switch_edu_id_issuer(%{String.t() => String.t()}, Map.t()) :: Map.t()
  def switch_edu_id_issuer(
        env \\ System.get_env(),
        default_config \\ :ueberauth_oidcc
        |> Application.fetch_env!(:issuers)
        |> Enum.find(fn issuer -> issuer[:name] == :switch_edu_id end)
      ) do
    %{
      name: :switch_edu_id,
      issuer: switch_edu_id_issuer_url(env, default_config)
    }
  end

  defp switch_edu_id_issuer_url(env, default_config) do
    "Switch edu-ID OpenID Connect issuer URL"
    |> ConfigValue.new()
    |> ConfigValue.env_var(env, "ARCHIDEP_AUTH_SWITCH_EDU_ID_ISSUER_URL")
    |> ConfigValue.default_to(default_config, [:issuer])
    |> ConfigValue.required_value()
  end

  @doc """
  Read the dynamic credentials for the Switch edu-ID authentication provider.
  """
  @spec switch_edu_id_auth_credentials(%{String.t() => String.t()}) :: Keyword.t()
  @spec switch_edu_id_auth_credentials(%{String.t() => String.t()}, Keyword.t()) :: Keyword.t()
  def switch_edu_id_auth_credentials(
        env \\ System.get_env(),
        default_config \\ Application.fetch_env!(:ueberauth_oidcc, :providers)
      ) do
    [
      client_id: switch_edu_id_client_id(env, default_config),
      client_secret: switch_edu_id_client_secret(env, default_config)
    ]
  end

  defp switch_edu_id_client_id(env, default_config) do
    "Switch edu-ID client ID for OpenID Connect authentication"
    |> ConfigValue.new()
    |> ConfigValue.env_var(env, "ARCHIDEP_AUTH_SWITCH_EDU_ID_CLIENT_ID")
    |> ConfigValue.default_to(default_config, [:switch_edu_id, :client_id])
    |> ConfigValue.required_value()
  end

  defp switch_edu_id_client_secret(env, default_config) do
    "Switch edu-ID client secret for OpenID Connect authentication"
    |> ConfigValue.new()
    |> ConfigValue.env_var(env, "ARCHIDEP_AUTH_SWITCH_EDU_ID_CLIENT_SECRET")
    |> ConfigValue.default_to(default_config, [:switch_edu_id, :client_secret])
    |> ConfigValue.required_value()
  end

  defp endpoint_http(env, default_config),
    do: [
      ip:
        "Endpoint HTTP bind IP"
        |> ConfigValue.new()
        |> ConfigValue.env_var(env, "ARCHIDEP_WEB_ENDPOINT_HTTP_IP", &parse_ip_address/1)
        |> ConfigValue.default_to(default_config, [:http, :ip])
        |> ConfigValue.validate(&validate_ip_address/1)
        |> ConfigValue.required_value(),
      port:
        "Endpoint HTTP port"
        |> ConfigValue.new()
        |> ConfigValue.env_var(env, "ARCHIDEP_WEB_ENDPOINT_HTTP_PORT", &parse_port/1)
        |> ConfigValue.default_to(default_config, [:http, :port])
        |> ConfigValue.validate(&validate_port/1)
        |> ConfigValue.required_value()
    ]

  defp endpoint_live_view(env, default_config),
    do: [
      signing_salt:
        "Endpoint live view signing salt"
        |> ConfigValue.new()
        |> ConfigValue.format(
          ~s/It must be a random string at least 20 bytes long.\nYou can generate one by calling "mix phx.gen.secret"./
        )
        |> ConfigValue.env_var(env, "ARCHIDEP_WEB_ENDPOINT_LIVE_VIEW_SIGNING_SALT")
        |> ConfigValue.default_to(default_config, [:live_view, :signing_salt])
        |> ConfigValue.validate(&validate_signing_salt/1)
        |> ConfigValue.required_value()
    ]

  defp endpoint_secret_key_base(env, default_config),
    do:
      "Endpoint secret key base"
      |> ConfigValue.new()
      |> ConfigValue.format(
        ~s/It must be a random string at least 50 bytes long.\nYou can generate one by calling "mix phx.gen.secret"./
      )
      |> ConfigValue.env_var(env, "ARCHIDEP_WEB_ENDPOINT_SECRET_KEY_BASE")
      |> ConfigValue.default_to(default_config, :secret_key_base)
      |> ConfigValue.validate(&validate_secret_key_base/1)
      |> ConfigValue.required_value()

  defp endpoint_session_signing_salt(env, default_config),
    do:
      "Endpoint session signing salt"
      |> ConfigValue.new()
      |> ConfigValue.format(
        ~s/It must be a random string at least 20 bytes long.\nYou can generate one by calling "mix phx.gen.secret"./
      )
      |> ConfigValue.env_var(env, "ARCHIDEP_WEB_ENDPOINT_SESSION_SIGNING_SALT")
      |> ConfigValue.default_to(default_config, :session_signing_salt)
      |> ConfigValue.validate(&validate_signing_salt/1)
      |> ConfigValue.required_value()

  defp endpoint_uploads_directory(env, default_config),
    do:
      "Endpoint uploads directory"
      |> ConfigValue.new()
      |> ConfigValue.format(
        ~s|It must be the path to a writable directory, for example:\n\n    /var/lib/app/uploads|
      )
      |> ConfigValue.env_var(env, "ARCHIDEP_WEB_ENDPOINT_UPLOADS_DIRECTORY")
      |> ConfigValue.default_to(default_config, :uploads_directory)
      |> ConfigValue.validate(&validate_uploads_directory/1)
      |> ConfigValue.required_value()

  defp endpoint_url(env, default_config),
    do:
      "Endpoint URL"
      |> ConfigValue.new()
      |> ConfigValue.format(
        ~s|It must be an HTTP(S) URL with scheme, host, port and path components, for example:\n\n    https://example.com/path|
      )
      |> ConfigValue.env_var(env, "ARCHIDEP_WEB_ENDPOINT_URL", &parse_http_url/1)
      |> ConfigValue.default_to(default_config, :url)
      |> ConfigValue.validate(&validate_endpoint_url/1)
      |> ConfigValue.required_value()

  defp parse_http_url(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme, host: host} = uri}
      when (scheme == "http" or scheme == "https") and is_binary(host) and host != "" ->
        {:ok,
         uri
         |> Map.from_struct()
         |> Map.reject(fn {_key, val} -> is_nil(val) end)
         |> Enum.into([])}

      _anything_else ->
        :error
    end
  end

  defp parse_ip_address(value) when is_binary(value) do
    case value |> to_charlist() |> :inet.parse_address() do
      {:ok, parsed} -> {:ok, parsed}
      _anything_else -> :error
    end
  end

  defp parse_port(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> {:ok, parsed}
      _anything_else -> :error
    end
  end

  defp validate_ip_address({a, b, c, d})
       when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255,
       do: true

  defp validate_ip_address({a, b, c, d, e, f, g, h})
       when a in 0..65_535 and b in 0..65_535 and c in 0..65_535 and d in 0..65_535 and
              e in 0..65_535 and f in 0..65_535 and g in 0..65_535 and h in 0..65_535,
       do: true

  defp validate_ip_address(_value), do: false

  defp validate_signing_salt(value) when is_binary(value) and byte_size(value) >= 20,
    do: true

  defp validate_signing_salt(value) when is_binary(value), do: false

  defp validate_secret_key_base(value) when is_binary(value) and byte_size(value) >= 50, do: true
  defp validate_secret_key_base(value) when is_binary(value), do: false

  defp validate_endpoint_url(value) when is_list(value) do
    scheme = Keyword.get(value, :scheme)
    port = Keyword.get(value, :port)

    cond do
      scheme != nil and scheme != "http" and scheme != "https" -> false
      Keyword.keys(value) -- [:scheme, :host, :port, :path] != [] -> false
      true -> port == nil or validate_endpoint_url_port(port)
    end
  end

  defp validate_endpoint_url_port(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> validate_port(parsed)
      :error -> false
    end
  end

  defp validate_endpoint_url_port(value), do: validate_port(value)

  defp validate_port(value)
       when is_integer(value) and value >= 1 and value <= 65_535,
       do: true

  defp validate_port(_value), do: false

  defp validate_uploads_directory(path),
    do: validate_writable_directory(path, :uploads_directory)

  defp validate_writable_directory(path, error_key) do
    case File.stat(path) do
      {:ok, stat} ->
        case {stat.type, stat.access} do
          {:directory, :read_write} -> {:ok, path}
          {:directory, _any_other_permissions} -> {:error, {error_key, :not_writable, path}}
          _not_a_directory -> {:error, {error_key, :not_a_directory, path}}
        end

      {:error, reason} ->
        {:error, {error_key, reason, path}}
    end
  end
end
