defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueClientBehaviour do
  @moduledoc """
  Behaviour of the client API of
  `ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue` used to query the
  health of the Ansible pipeline queue.

  It is implemented in production by the `AnsiblePipelineQueue` GenStage and
  swapped for a mock in the test environment so that callers such as the health
  controller can be tested in isolation.
  """

  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue.State

  @callback health(Pipeline.t()) :: State.health_data()
end
