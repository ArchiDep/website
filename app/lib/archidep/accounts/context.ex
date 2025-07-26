defmodule ArchiDep.Accounts.Context do
  @moduledoc false

  @behaviour ArchiDep.Accounts.Behaviour

  use ArchiDep, :context_impl

  alias ArchiDep.Accounts.Behaviour
  alias ArchiDep.Accounts.UseCases

  implement(
    &Behaviour.log_in_or_register_with_switch_edu_id/2,
    UseCases.LogInOrRegisterWithSwitchEduId
  )

  implement(&Behaviour.validate_session_token/2, UseCases.Sessions)
  implement(&Behaviour.validate_session_id/2, UseCases.Sessions)
  implement(&Behaviour.fetch_active_sessions/1, UseCases.Sessions)
  implement(&Behaviour.impersonate/2, UseCases.Impersonate)
  implement(&Behaviour.stop_impersonating/1, UseCases.Impersonate)
  implement(&Behaviour.delete_session/2, UseCases.DeleteSession)
  implement(&Behaviour.log_out/1, UseCases.LogOut)

  implement(&Behaviour.user_account/1, UseCases.Sessions)
end
