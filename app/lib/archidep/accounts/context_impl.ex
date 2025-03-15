defmodule ArchiDep.Accounts.ContextImpl do
  @moduledoc false

  @behaviour ArchiDep.Accounts.Behaviour

  import ArchiDep.Helpers.ContextHelpers, only: [implement: 2, implement: 3]
  alias ArchiDep.Accounts.Behaviour

  implement(
    &Behaviour.log_in_or_register_with_switch_edu_id/2,
    ArchiDep.Accounts.LogInOrRegisterWithSwitchEduId
  )
end
