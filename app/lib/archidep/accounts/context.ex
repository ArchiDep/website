defmodule ArchiDep.Accounts.Context do
  @moduledoc false

  @behaviour ArchiDep.Accounts.Behaviour

  alias ArchiDep.Accounts.Behaviour
  alias ArchiDep.Accounts.UseCases

  @doc false
  @impl Behaviour
  defdelegate log_in_or_register_with_switch_edu_id(data, meta),
    to: UseCases.LogInOrRegisterWithSwitchEduId

  @doc false
  @impl Behaviour
  defdelegate log_in_or_register_with_link(token, meta), to: UseCases.LogInOrRegisterWithLink

  @doc false
  @impl Behaviour
  defdelegate validate_session_token(token, meta), to: UseCases.Sessions

  @doc false
  @impl Behaviour
  defdelegate validate_session_id(id, meta), to: UseCases.Sessions

  @doc false
  @impl Behaviour
  defdelegate fetch_active_sessions(auth), to: UseCases.Sessions

  @doc false
  @impl Behaviour
  defdelegate impersonate(auth, user_id), to: UseCases.Impersonate

  @doc false
  @impl Behaviour
  defdelegate stop_impersonating(auth), to: UseCases.Impersonate

  @doc false
  @impl Behaviour
  defdelegate delete_session(auth, id), to: UseCases.DeleteSession

  @doc false
  @impl Behaviour
  defdelegate user_account(auth), to: UseCases.Sessions

  @doc false
  @impl Behaviour
  defdelegate log_out(auth), to: UseCases.LogOut

  @doc false
  @impl Behaviour
  defdelegate create_login_link_for_preregistered_user(auth, preregistered_user_id),
    to: UseCases.CreateLoginLinks
end
