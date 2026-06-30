defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineSupervisorTest do
  # End-to-end smoke test of the whole pipeline: the unit tests mock each stage
  # boundary, so this is the only test that proves the stages are wired together
  # — the consumer subscribes to the queue, demand flows, and a runner task is
  # spawned per event to invoke Ansible and the server manager.
  #
  # `async: false` + `Mox.set_mox_global/0`: the runner runs in a task spawned
  # by the consumer (a different process), so the mocks must be global;
  # shared-mode sandbox covers that task's database reads and the queue's boot
  # cleanup.
  use ArchiDep.Support.DataCase, async: false

  import Hammox
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineSupervisor
  alias ArchiDep.Servers.ServerTracking.ServerManagerClientMock
  alias ArchiDep.Support.ServersTestHelpers

  @past ~U[2024-01-01 00:00:00.000000Z]

  setup :set_mox_global
  setup :verify_on_exit!

  setup %{test: test} do
    %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
    server = ServersTestHelpers.insert_server(owner.id, class.id, active: true)

    start_supervised!({AnsiblePipelineSupervisor, test})

    %{server: server, pipeline: test}
  end

  test "runs a queued gather-facts task through every stage", %{
    server: server,
    pipeline: pipeline
  } do
    test_pid = self()
    facts = %{"ansible_distribution" => "Ubuntu"}

    stub(ServerManagerClientMock, :online?, fn ^server -> true end)

    expect(Ansible.Mock, :gather_facts, fn ^server, "deploy" ->
      send(test_pid, :gather_facts_called)
      {:ok, facts}
    end)

    expect(ServerManagerClientMock, :ansible_facts_gathered, fn ^server, {:ok, ^facts} ->
      send(test_pid, :facts_reported)
      :ok
    end)

    assert AnsiblePipelineQueue.gather_facts(pipeline, server, "deploy") == :ok

    # The task is spawned asynchronously by the consumer; await its observable
    # effects rather than sleeping.
    assert_receive :gather_facts_called, 1000
    assert_receive :facts_reported, 1000
  end
end
