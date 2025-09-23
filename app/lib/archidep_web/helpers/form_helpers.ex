defmodule ArchiDepWeb.Helpers.FormHelpers do
  @moduledoc """
  Helper functions for web form handling.
  """

  @spec tmp_boolify(map(), String.t()) :: map()
  def tmp_boolify(params, key) when is_binary(key) do
    case params do
      %{^key => "true"} -> %{params | key => true}
      %{^key => "false"} -> %{params | key => false}
      _anything_else -> params
    end
  end
end
