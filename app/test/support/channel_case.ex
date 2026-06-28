defmodule ArchiDepWeb.Support.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also import other functionality
  to make it easier to build common data structures and query the data layer.

  Like the LiveView and controller tests (see
  `ArchiDepWeb.Support.LiveCase`/`ArchiDepWeb.Support.ConnCase`), channel tests
  run against the `Hammox` context mocks rather than the real contexts: the
  default clock is stubbed to the system clock and `verify_on_exit!` enforces
  the expectations set in each test. The `Phoenix.PubSub` server is the real
  one, so a test drives the channel's `handle_info/2` clauses by broadcasting on
  the topics the channel subscribes to.

  Finally, if the test case interacts with the database, we enable the SQL
  sandbox, so changes done to the database are reverted at the end of every
  test. If you are using PostgreSQL, you can even run database tests
  asynchronously by setting `use ArchiDepWeb.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  import Hammox
  alias ArchiDep.Clock.SystemClock
  alias ArchiDep.Support.DataCase
  alias Ecto.UUID
  alias Phoenix.Token

  using do
    quote do
      # The default endpoint for testing
      @endpoint ArchiDepWeb.Endpoint

      # Import conveniences for testing with channels
      import ArchiDep.Helpers.PipeHelpers
      import ArchiDepWeb.Support.ChannelCase
      import Hammox
      import Phoenix.ChannelTest
      alias ArchiDepWeb.Channels.UserChannel
      alias ArchiDepWeb.Channels.UserSocket
      alias Ecto.UUID
    end
  end

  setup tags do
    DataCase.setup_sandbox(tags)

    # Default the injectable clock to the real system clock; a test that needs
    # deterministic time-dependent behaviour overrides this with a fixed
    # instant.
    Hammox.stub(ArchiDep.Clock.Mock, :now, &SystemClock.now/0)

    :ok
  end

  setup :verify_on_exit!

  @doc """
  Signs a user socket token the way `AuthController.generate_socket_token/2`
  does, so a connect test can drive `UserSocket.connect/3` with a token the
  endpoint will verify. Pass `signed_at:` (a Unix timestamp in seconds) to forge
  an expired token.
  """
  @spec sign_user_socket_token(UUID.t(), keyword()) :: String.t()
  def sign_user_socket_token(session_id, opts \\ []) when is_binary(session_id) and is_list(opts),
    do: Token.sign(ArchiDepWeb.Endpoint, "user socket", session_id, opts)
end
