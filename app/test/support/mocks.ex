Hammox.defmock(ArchiDep.Accounts.ContextMock,
  for: ArchiDep.Accounts.Behaviour,
  moduledoc: """
  Mock of the accounts context.
  """
)

Hammox.defmock(ArchiDep.Course.ContextMock,
  for: ArchiDep.Course.Behaviour,
  moduledoc: """
  Mock of the course context.
  """
)

Hammox.defmock(ArchiDep.Events.ContextMock,
  for: ArchiDep.Events.Behaviour,
  moduledoc: """
  Mock of the events context.
  """
)

Hammox.defmock(ArchiDep.Servers.ContextMock,
  for: ArchiDep.Servers.Behaviour,
  moduledoc: """
  Mock of the servers context.
  """
)

Hammox.defmock(ArchiDep.Servers.ServerTracking.ServerManagerMock,
  for: ArchiDep.Servers.ServerTracking.ServerManagerBehaviour,
  moduledoc: """
  Mock of the module responsible for managing interactions with a registered server.
  """
)

Hammox.defmock(ArchiDep.Servers.Ansible.Mock,
  for: ArchiDep.Servers.Ansible.Behaviour,
  moduledoc: """
  Mock of the Ansible context.
  """
)

Hammox.defmock(ArchiDep.Http.Mock,
  for: ArchiDep.Http.Behaviour,
  moduledoc: """
  Mock of the HTTP client.
  """
)
