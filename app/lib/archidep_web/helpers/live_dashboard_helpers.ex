defmodule ArchiDepWeb.LiveDashboardHelpers do
  @moduledoc """
  Helper functions for the Phoenix live dashboard. See
  https://github.com/phoenixframework/phoenix_live_dashboard.
  """

  @envs [:dev, :test]

  @doc """
  Returns the environments in which the live dashboard is enabled.
  """
  @spec live_dashboard_envs() :: list(atom)
  def live_dashboard_envs, do: @envs

  @doc """
  Indicates whether the live dashboard is enabled for the specified environment.
  """
  @spec live_dashboard?(atom) :: boolean

  if Mix.env() in @envs do
    def live_dashboard?(env) when env in [:dev, :test], do: true
  end

  def live_dashboard?(_any_other_environment), do: false
end
