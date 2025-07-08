defmodule ArchiDep.Accounts do
  @moduledoc """
  User account management context.
  """

  @behaviour ArchiDep.Accounts.Behaviour

  import ArchiDep.Helpers.ContextHelpers, only: [delegate: 1]
  alias ArchiDep.Accounts.Behaviour

  @implementation Application.compile_env!(:archidep, __MODULE__)

  delegate(&Behaviour.log_in_or_register_with_switch_edu_id/2)
  delegate(&Behaviour.validate_session/2)
  delegate(&Behaviour.fetch_active_sessions/1)
  delegate(&Behaviour.impersonate/2)
  delegate(&Behaviour.stop_impersonating/1)
  delegate(&Behaviour.delete_session/2)
  delegate(&Behaviour.user_account/1)
  delegate(&Behaviour.log_out/1)
end
