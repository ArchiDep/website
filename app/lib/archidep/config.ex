defmodule ArchiDep.Config do
  @moduledoc """
  This module retrieves configuration values for the application from the
  environment and the application configuration, applying appropriate precedence
  rules: values from environment variables always take precedence over
  application values.
  """

  alias ArchiDep.Config.ConfigValue
  alias ArchiDep.Repo
  require Logger

  @doc """
  Logs the current configuration of the application.
  """
  @spec log() :: :ok
  def log do
    auth_config = Application.fetch_env!(:archidep, :auth)
    servers_config = Application.fetch_env!(:archidep, :servers)
    repo_config = Application.fetch_env!(:archidep, Repo)

    safe_repo_url =
      repo_config
      |> Keyword.fetch!(:url)
      |> URI.new!()
      |> then(fn
        %URI{userinfo: userinfo} = uri when is_binary(userinfo) ->
          %URI{uri | userinfo: String.replace(userinfo, ~r/:.+/, "**********")}

        uri_without_userinfo ->
          uri_without_userinfo
      end)

    Logger.info(~s"""
    Configuration
    /
    |-> Authentication
    |   \\-> Switch edu-ID root users: #{inspect(auth_config[:root_users][:switch_edu_id])}
    |-> Servers
    |   |-> Connection timeout: #{inspect(servers_config[:connection_timeout])}
    |   |-> Public key: #{inspect(servers_config[:ssh_public_key])}
    |   |-> SSH directory: #{inspect(servers_config[:ssh_dir])}
    |   \\-> Track: #{inspect(servers_config[:track_on_boot])}
    \\-> Repository
        |-> URL: #{inspect(URI.to_string(safe_repo_url))}
        |-> Pool size: #{inspect(repo_config[:pool_size])}
        \\-> Socket options: #{inspect(repo_config[:socket_options])}
    """)
  end

  @doc """
  Read the dynamic application authentication configuration.
  """
  @spec auth(%{String.t() => String.t()}, keyword) :: keyword
  def auth(env \\ System.get_env(), default_config \\ Application.fetch_env!(:archidep, :auth)) do
    [
      root_users: [switch_edu_id: app_root_users(env, default_config)]
    ]
  end

  defp app_root_users(env, default_config),
    do:
      "Application root users"
      |> ConfigValue.new()
      |> ConfigValue.format(
        "It must be a comma-separated list of emails or swissEduPersonUniqueID of switch edu-ID users."
      )
      |> ConfigValue.env_var(
        env,
        "ARCHIDEP_AUTH_SWITCH_EDU_ID_ROOT_USERS",
        &parse_comma_separated_list/1
      )
      |> ConfigValue.default_to(default_config, [:root_users, :switch_edu_id])
      |> ConfigValue.validate(&validate_string_list!/1)
      |> ConfigValue.required_value()

  @doc """
  Read the dynamic application configuration for server-related functionality.
  """
  @spec servers(%{String.t() => String.t()}, keyword) :: keyword
  def servers(
        env \\ System.get_env(),
        default_config \\ Application.fetch_env!(:archidep, :servers)
      ) do
    [
      ssh_dir: ssh_dir(env, default_config),
      ssh_public_key: ssh_public_key(env, default_config)
    ]
  end

  defp ssh_dir(env, default_config),
    do:
      "SSH directory"
      |> ConfigValue.new()
      |> ConfigValue.format(
        "It must be the path to a readable directory containing an SSH private key file with a standard name."
      )
      |> ConfigValue.env_var(env, "ARCHIDEP_SERVERS_SSH_DIR")
      |> ConfigValue.default_to(default_config, :ssh_dir)
      |> ConfigValue.validate(&validate_ssh_directory/1)
      |> ConfigValue.required_value()

  defp ssh_public_key(env, default_config),
    do:
      "Public key"
      |> ConfigValue.new()
      |> ConfigValue.format("It must be an SSH public key.")
      |> ConfigValue.env_var(env, "ARCHIDEP_SERVERS_SSH_PUBLIC_KEY")
      |> ConfigValue.default_to(default_config, :ssh_public_key)
      |> ConfigValue.required_value()

  @doc """
  Read the dynamic persistence repository configuration.
  """
  @spec repo(%{String.t() => String.t()}, keyword) :: keyword
  def repo(env \\ System.get_env(), default_config \\ Application.fetch_env!(:archidep, Repo)) do
    opts = [
      pool_size: repo_pool_size(env, default_config),
      # ssl: true,
      socket_options: repo_socket_options(env, default_config),
      url: repo_url(env, default_config)
    ]

    Keyword.reject(opts, fn {_key, value} -> is_nil(value) end)
  end

  defp repo_pool_size(env, default_config),
    do:
      "Repo pool size"
      |> ConfigValue.new()
      |> ConfigValue.format("It must be an integer between 1 and 100.")
      |> ConfigValue.env_var(env, "ARCHIDEP_REPO_POOL_SIZE", &parse_integer/1)
      |> ConfigValue.default_to(default_config, :pool_size)
      |> ConfigValue.validate(&validate_integer!(&1, 1, 100))
      |> ConfigValue.optional_value()

  defp repo_socket_options(env, default_config),
    do:
      Keyword.get(default_config, :socket_options, []) ++
        (if "Repo IPv6 flag"
            |> ConfigValue.new()
            |> ConfigValue.format(~s/It must be a boolean, e.g. "true" or "false"./)
            |> ConfigValue.env_var(env, "ARCHIDEP_REPO_IPV6", &parse_boolean/1)
            |> ConfigValue.optional_value() do
           [:inet6]
         else
           []
         end)

  defp repo_url(env, default_config),
    do:
      "Repo URL"
      |> ConfigValue.new()
      |> ConfigValue.format(
        ~s|It must be an Ecto database URL with the "ecto://" scheme, for example:\n\n    ecto://<user>:<password>@<host>:<port>/<database>|
      )
      |> ConfigValue.env_var(env, "ARCHIDEP_REPO_URL")
      |> ConfigValue.default_to(default_config, :url)
      |> ConfigValue.validate(&validate_ecto_url!/1)
      |> ConfigValue.required_value()

  defp parse_boolean(value) when is_binary(value) do
    cond do
      String.match?(value, ~r/^(?:1|y|yes|t|true)$/) ->
        {:ok, true}

      String.match?(value, ~r/(?:0|n|no|f|false)$/) ->
        {:ok, false}

      true ->
        :error
    end
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> {:ok, parsed}
      _anything_else -> :error
    end
  end

  defp parse_comma_separated_list(value) when is_binary(value),
    do:
      value
      |> String.split(",")
      |> Enum.reduce_while([], fn part, acc ->
        case String.trim(part) do
          "" -> {:halt, {:error, "Blank string in comma-separated list"}}
          trimmed_part -> {:cont, [trimmed_part | acc]}
        end
      end)
      |> then(fn
        list when is_list(list) -> {:ok, Enum.reverse(list)}
        {:error, reason} -> {:error, reason}
      end)

  defp validate_integer!(value, min, max)
       when is_integer(value) and is_integer(min) and is_integer(max) and min <= max and
              value >= min and value <= max,
       do: true

  defp validate_integer!(_value, min, max)
       when is_integer(min) and is_integer(max) and min <= max,
       do: false

  defp validate_ecto_url!(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{host: host, path: path, scheme: "ecto"}}
      when is_binary(host) and is_binary(path) and path != "/" ->
        true

      _anything_else ->
        false
    end
  end

  defp validate_ssh_directory(path) do
    private_key_file = Path.join(path, "id_ed25519")

    with {:ok, ^path} <- validate_readable_directory(path, :ssh_dir),
         {:ok, ^private_key_file} <-
           validate_readable_file(private_key_file, :ssh_dir_private_key_file) do
      {:ok, path}
    end
  end

  defp validate_readable_directory(path, error_key) when is_atom(error_key) do
    case File.stat(path) do
      {:ok, stat} ->
        case {stat.type, stat.access} do
          {:directory, permission} when permission in [:read, :read_write] -> {:ok, path}
          {:directory, _any_other_permissions} -> {:error, {error_key, :not_readable}}
          _not_a_directory -> {:error, {error_key, :not_a_directory}}
        end

      {:error, reason} ->
        {:error, {error_key, reason}}
    end
  end

  defp validate_readable_file(path, error_key) when is_atom(error_key) do
    case File.stat(path) do
      {:ok, stat} ->
        case {stat.type, stat.access} do
          {:regular, permission} when permission in [:read, :read_write] -> {:ok, path}
          {:regular, _any_other_permissions} -> {:error, {error_key, :not_readable}}
          _not_a_directory -> {:error, {error_key, :not_a_file}}
        end

      {:error, reason} ->
        {:error, {error_key, reason}}
    end
  end

  defp validate_string_list!(list) when is_list(list),
    do: Enum.all?(list, fn part -> is_binary(part) and String.trim(part) != "" end)
end
