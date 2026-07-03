{:ok, _apps} = Application.ensure_all_started(:ex_machina)

# External-tool compatibility smoke tests (tagged `:external`) drive the real
# `ansible`/`ssh` tools instead of their mocks, so they need those tools present
# and must not taint the coverage numbers. They are excluded from the default
# run and opted into with `mix test --only external` in a dedicated CI job. See
# the "Testing external-tool compatibility" section in `docs/testing.md`.
ExUnit.start(exclude: [external: true])

Ecto.Adapters.SQL.Sandbox.mode(ArchiDep.Repo, :manual)
