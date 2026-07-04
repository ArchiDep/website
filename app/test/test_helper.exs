{:ok, _apps} = Application.ensure_all_started(:ex_machina)

# External-tool compatibility smoke tests (tagged `:external`) drive the real
# `ansible`/`ssh` tools instead of their mocks, so they need those tools present
# and must not taint the coverage numbers. They are excluded from the default
# run and opted into with `mix test --only external` in a dedicated CI job. See
# the "Testing external-tool compatibility" section in `docs/testing.md`.
#
# `assert_receive_timeout: 500` (up from the 100ms default): many
# server-tracking tests wait on a message a spawned GenServer/task sends, and
# under the fully concurrent async suite the scheduler can delay delivery past
# 100ms, failing the assertion spuriously. A passing `assert_receive` returns as
# soon as the message arrives, so the higher ceiling only affects genuine
# failures, not runtime.
ExUnit.start(exclude: [external: true], assert_receive_timeout: 500)

Ecto.Adapters.SQL.Sandbox.mode(ArchiDep.Repo, :manual)
