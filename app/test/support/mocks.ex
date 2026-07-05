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

Hammox.defmock(ArchiDep.Servers.ServerTracking.ServerManagerClientMock,
  for: ArchiDep.Servers.ServerTracking.ServerManagerClientBehaviour,
  moduledoc: """
  Mock of the client API of the module responsible for managing interactions with a registered server.
  """
)

Hammox.defmock(ArchiDep.Servers.ServerTracking.ServersOrchestratorClientMock,
  for: ArchiDep.Servers.ServerTracking.ServersOrchestratorBehaviour,
  moduledoc: """
  Mock of the client API of the orchestrator responsible for tracking active servers.
  """
)

Hammox.defmock(ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueClientMock,
  for: ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueClientBehaviour,
  moduledoc: """
  Mock of the client API used to query the health of the Ansible pipeline queue.
  """
)

Hammox.defmock(ArchiDep.Servers.ServerTracking.ServerTrackerClientMock,
  for: ArchiDep.Servers.ServerTracking.ServerTrackerClientBehaviour,
  moduledoc: """
  Mock of the client API of the tracker responsible for the real-time state of servers.
  """
)

Hammox.defmock(ArchiDep.Servers.ServerTracking.ServersOrchestratorStoreMock,
  for: ArchiDep.Servers.ServerTracking.ServersOrchestratorStoreBehaviour,
  moduledoc: """
  Mock of the store used by the servers orchestrator to read which servers to track.
  """
)

Hammox.defmock(ArchiDep.Servers.ServerTracking.ServerSupervisorStarterMock,
  for: ArchiDep.Servers.ServerTracking.ServerSupervisorStarterBehaviour,
  moduledoc: """
  Mock of the collaborator used by the servers orchestrator to start per-server supervisors.
  """
)

Hammox.defmock(ArchiDep.Servers.Ansible.Mock,
  for: ArchiDep.Servers.Ansible.Behaviour,
  moduledoc: """
  Mock of the Ansible context.
  """
)

Hammox.defmock(ArchiDep.Cmd.Mock,
  for: ArchiDep.Cmd.Behaviour,
  moduledoc: """
  Mock of the module used to run external commands and stream their output.
  """
)

Hammox.defmock(ArchiDep.Http.Mock,
  for: ArchiDep.Http.Behaviour,
  moduledoc: """
  Mock of the HTTP client.
  """
)

Hammox.defmock(ArchiDep.Servers.SSH.Client.Mock,
  for: ArchiDep.Servers.SSH.Client.Behaviour,
  moduledoc: """
  Mock of the module used to open SSH connections and run commands over them.
  """
)

Hammox.defmock(ArchiDep.Clock.Mock,
  for: ArchiDep.Clock.Behaviour,
  moduledoc: """
  Mock of the clock used to obtain the current time.
  """
)

Hammox.defmock(ArchiDep.PubSub.Scope.Mock,
  for: ArchiDep.PubSub.Scope.Behaviour,
  moduledoc: """
  Mock of the PubSub topic scope used to isolate global topics per test.
  """
)

Hammox.defmock(ArchiDep.TrackerClientMock,
  for: ArchiDep.TrackerClientBehaviour,
  moduledoc: """
  Mock of the client API of the presence tracker.
  """
)
