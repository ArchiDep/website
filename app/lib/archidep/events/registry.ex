defmodule ArchiDep.Events.Registry do
  @moduledoc """
  Business event registry for the application.
  """

  use ArchiDep.Events.Store.Registry

  alias ArchiDep.Accounts.Events.SessionDeleted
  alias ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId
  alias ArchiDep.Accounts.Events.UserLoggedOut
  alias ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId
  alias ArchiDep.Students.Events.ClassCreated

  event(ClassCreated,
    prefix: "classes:",
    by: :id,
    type: :"archidep/students/class-created"
  )

  event(SessionDeleted,
    prefix: "user-accounts:",
    by: :user_account_id,
    type: :"archidep/accounts/session-deleted"
  )

  event(UserLoggedInWithSwitchEduId,
    prefix: "user-accounts:",
    by: :user_account_id,
    type: :"archidep/accounts/user-logged-in-with-switch-edu-id"
  )

  event(UserLoggedOut,
    prefix: "user-accounts:",
    by: :user_account_id,
    type: :"archidep/accounts/user-logged-out"
  )

  event(UserRegisteredWithSwitchEduId,
    prefix: "user-accounts:",
    by: :user_account_id,
    type: :"archidep/accounts/user-registered-with-switch-edu-id"
  )
end
