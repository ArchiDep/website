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
  alias ArchiDep.Students.Events.ClassDeleted
  alias ArchiDep.Students.Events.ClassUpdated
  alias ArchiDep.Students.Events.StudentCreated
  alias ArchiDep.Students.Events.StudentDeleted
  alias ArchiDep.Students.Events.StudentUpdated

  event(ClassCreated,
    prefix: "classes:",
    by: :id,
    type: :"archidep/students/class-created"
  )

  event(ClassDeleted,
    prefix: "classes:",
    by: :id,
    type: :"archidep/students/class-deleted"
  )

  event(ClassUpdated,
    prefix: "classes:",
    by: :id,
    type: :"archidep/students/class-updated"
  )

  event(StudentCreated,
    prefix: "students:",
    by: :id,
    type: :"archidep/students/student-created"
  )

  event(StudentUpdated,
    prefix: "students:",
    by: :id,
    type: :"archidep/students/student-updated"
  )

  event(StudentDeleted,
    prefix: "students:",
    by: :id,
    type: :"archidep/students/student-deleted"
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
