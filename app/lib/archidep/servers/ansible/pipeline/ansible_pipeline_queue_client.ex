defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueClient do
  @moduledoc """
  Access to the client API of
  `ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue` through an injectable
  implementation.

  The health controller queries the pipeline queue through this module instead
  of calling the GenStage directly. In production it delegates to
  `AnsiblePipelineQueue`; in the test environment it is configured to a mock so
  that callers can be tested in isolation.
  """

  @behaviour ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueClientBehaviour

  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate health(pipeline), to: @implementation
end
