defmodule ArchiDep.Config.ConfigValue do
  @moduledoc """
  This module reads a configuration value from an environment variable or from
  the application's configuration.
  """

  alias ArchiDep.Config.ConfigError

  @enforce_keys [:description]
  defstruct value: nil,
            original_value: nil,
            source: nil,
            description: nil,
            format_description: nil,
            sources: []

  @type config_source :: {:default_config, atom}
  @type env_var_source :: {:env_var, String.t()}
  @type source :: config_source | env_var_source

  @type env_var_parser :: (String.t() -> {:ok, term} | :error)

  @type t :: %__MODULE__{
          value: term,
          original_value: term,
          source: source | nil,
          description: String.t(),
          format_description: String.t() | nil,
          sources: list(source)
        }

  @doc """
  Create a new configuration value.
  """
  @spec new(String.t()) :: t()
  def new(description) when is_binary(description) do
    %__MODULE__{description: description}
  end

  @doc """
  Add a description of the expected format of the value. This description will
  be included in error messages.
  """
  @spec format(t(), String.t()) :: t()
  def format(config_value, description) when is_binary(description) do
    %__MODULE__{config_value | format_description: description}
  end

  @doc """
  Read the value from an environment variable.
  """
  @spec env_var(t(), %{String.t() => String.t()}, String.t(), env_var_parser) ::
          t()
  def env_var(
        config_value,
        env,
        name,
        parser \\ &no_op_parser/1
      )
      when is_map(env) and is_function(parser, 1) do
    sources = config_value.sources

    source = {:env_var, name}

    if value = Map.get(env, name) do
      case parser.(value) do
        {:ok, parsed} ->
          %__MODULE__{
            config_value
            | value: parsed,
              original_value: value,
              source: source,
              sources: [source | sources]
          }

        _anything_else ->
          raise ConfigError,
                format_error_message(%__MODULE__{
                  config_value
                  | value: value,
                    original_value: value,
                    source: source,
                    sources: [source | sources]
                })
      end
    else
      %__MODULE__{config_value | source: source, sources: [source | sources]}
    end
  end

  @doc """
  Read the value from the application's configuration. Has no effect if the
  value is already set.
  """
  @spec default_to(t(), list, atom | list(atom)) :: t()
  def default_to(%__MODULE__{value: nil} = config_value, default_config, key)
      when is_list(default_config) and is_atom(key) do
    default_to(config_value, default_config, [key])
  end

  def default_to(%__MODULE__{value: nil, sources: sources} = config_value, default_config, key)
      when is_list(default_config) and is_list(key) do
    value = get_in(default_config, key)
    source = {:default_config, key}

    %__MODULE__{
      config_value
      | value: value,
        original_value: value,
        source: source,
        sources: [source | sources]
    }
  end

  def default_to(config_value, _default_config, _key) do
    config_value
  end

  @doc """
  Validate the value with a custom function.
  """
  @spec validate(t(), (term -> boolean)) :: t()
  def validate(%__MODULE__{value: nil} = config_value, validator) when is_function(validator, 1),
    do: config_value

  def validate(config_value, validator)
      when is_function(validator, 1) do
    %__MODULE__{value: value} = config_value

    if validator.(value) do
      config_value
    else
      raise ConfigError, format_error_message(config_value)
    end
  end

  @doc """
  Get the configuration value, raising an error if it is not set.
  """
  @spec required_value(t()) :: term
  def required_value(%__MODULE__{value: nil} = config_value),
    do: raise(ConfigError, required_error_message(config_value))

  def required_value(%__MODULE__{value: value}), do: value

  @doc """
  Get the configuration value or nil if it is not set.
  """
  @spec optional_value(t()) :: term
  def optional_value(%__MODULE__{value: value}), do: value

  defp no_op_parser(value), do: {:ok, value}

  defp format_error_message(config_value) do
    %__MODULE__{
      original_value: original_value,
      source: source,
      description: desc,
      format_description: format
    } = config_value

    [
      "#{desc} #{inspect(original_value)} is invalid.",
      format,
      "This value was set in #{describe_source(source)}."
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp required_error_message(config_value) do
    %__MODULE__{description: desc, format_description: format, sources: sources} = config_value

    tips =
      sources
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {source, i} ->
        "#{if i == 0, do: "Set", else: "Or set"} it with #{describe_source(source)}."
      end)

    [
      "#{desc} is required but was not provided.",
      format,
      "",
      tips
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp describe_source({:default_config, _key}), do: "one of the \"config/*.exs\" files"
  defp describe_source({:env_var, name}), do: "environment variable $#{name}"
end
