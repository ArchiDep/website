defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueStoreBehaviour do
  @moduledoc """
  Behaviour of the store used by the Ansible pipeline queue for the database
  work it performs when it boots.

  It is injected into `ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue`
  at `start_link/2` (defaulting to
  `ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueStore`) rather than
  resolved through a compile-time configuration, because the call happens in
  `init/1` — before a test can allow the spawned queue process onto its mocks —
  so a test injects a plain fake instead.
  """

  @callback mark_incomplete_runs_as_timed_out() :: :ok
end
