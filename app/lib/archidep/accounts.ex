defmodule ArchiDep.Accounts do
  @moduledoc """
  Accounts context, which concerns everything related to user accounts,
  including authentication, user sessions, and account management.
  """

  @behaviour ArchiDep.Accounts.Behaviour

  use ArchiDep, :context

  alias ArchiDep.Accounts.Behaviour

  @implementation Application.compile_env!(:archidep, __MODULE__)

  delegate(&Behaviour.log_in_or_register_with_switch_edu_id/2)
  delegate(&Behaviour.validate_session_token/2)
  delegate(&Behaviour.validate_session_id/2)
  delegate(&Behaviour.fetch_active_sessions/1)
  delegate(&Behaviour.impersonate/2)
  delegate(&Behaviour.stop_impersonating/1)
  delegate(&Behaviour.delete_session/2)
  delegate(&Behaviour.user_account/1)
  delegate(&Behaviour.log_out/1)
end
