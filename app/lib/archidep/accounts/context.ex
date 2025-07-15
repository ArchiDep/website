defmodule ArchiDep.Accounts.Context do
  @moduledoc false

  use ArchiDep, :context_impl

  @behaviour ArchiDep.Accounts.Behaviour

  alias ArchiDep.Accounts.Behaviour

  implement(
    &Behaviour.log_in_or_register_with_switch_edu_id/2,
    ArchiDep.Accounts.LogInOrRegisterWithSwitchEduId
  )

  implement(&Behaviour.validate_session/2, ArchiDep.Accounts.Sessions)
  implement(&Behaviour.fetch_active_sessions/1, ArchiDep.Accounts.Sessions)
  implement(&Behaviour.impersonate/2, ArchiDep.Accounts.Impersonate)
  implement(&Behaviour.stop_impersonating/1, ArchiDep.Accounts.Impersonate)
  implement(&Behaviour.delete_session/2, ArchiDep.Accounts.DeleteSession)

  implement(&Behaviour.user_account/1, ArchiDep.Accounts.Sessions)

  implement(&Behaviour.log_out/1, ArchiDep.Accounts.LogOut)
end
