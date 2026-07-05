{:ok, _apps} = Application.ensure_all_started(:ex_machina)

# Tests tagged `:external` drive a process outside the Elixir/Erlang ecosystem —
# the real `ansible`/`ansible-playbook` tools against a live host — instead of
# their mocks, so they need that tool present and must not taint the coverage
# numbers. They are excluded from the default run and opted into with `mix test
# --only external` in a dedicated CI job. The SSH compatibility smoke test
# drives the in-process Erlang `:ssh` stack (within the ecosystem), so it is not
# tagged and runs here. See the "Testing external-tool compatibility" section in
# `docs/testing.md`.
#
# `assert_receive_timeout: 500` (up from the 100ms default): many
# server-tracking tests wait on a message a spawned GenServer/task sends, and
# under the fully concurrent async suite the scheduler can delay delivery past
# 100ms, failing the assertion spuriously. A passing `assert_receive` returns as
# soon as the message arrives, so the higher ceiling only affects genuine
# failures, not runtime.
ExUnit.start(exclude: [external: true], assert_receive_timeout: 500)

Ecto.Adapters.SQL.Sandbox.mode(ArchiDep.Repo, :manual)
