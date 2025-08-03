defmodule ArchiDep.Config do
  @moduledoc """
  This module retrieves configuration values for the application from the
  environment and the application configuration, applying appropriate precedence
  rules: values from environment variables always take precedence over
  application values.
  """

  alias ArchiDep.Config.ConfigValue
  alias ArchiDep.Repo

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

  defp validate_string_list!(list) when is_list(list),
    do: Enum.all?(list, fn part -> is_binary(part) and String.trim(part) != "" end)
end
