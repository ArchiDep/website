defmodule ArchiDep.Accounts.Schemas.UserSession do
  @moduledoc """
  A session representing the fact that a user is logged in with a browser. The
  session remains active until it either expires or is deleted by the user or an
  administrator.
  """

  use ArchiDep, :schema

  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.ClientMetadata

  @derive {Inspect, only: [:id, :created_at, :user_account]}
  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @session_token_bytes 50
  @session_validity_in_days 60
  @one_day_in_seconds 24 * 60 * 60

  @type t :: %__MODULE__{
          id: UUID.t(),
          token: String.t(),
          created_at: DateTime.t(),
          used_at: DateTime.t() | nil,
          client_ip_address: String.t() | nil,
          client_user_agent: String.t() | nil,
          user_account: UserAccount.t() | NotLoaded,
          user_account_id: UUID.t()
        }

  schema "user_sessions" do
    field(:token, :binary, redact: true)
    field(:created_at, :utc_datetime_usec)
    field(:used_at, :utc_datetime_usec)
    field(:client_ip_address, :string)
    field(:client_user_agent, :string)
    belongs_to(:user_account, UserAccount)
  end

  @doc """
  Returns the expiration date of the specified session.
  """
  @spec expires_at(__MODULE__.t()) :: DateTime.t()
  def expires_at(%__MODULE__{created_at: created_at}),
    do: DateTime.add(created_at, @session_validity_in_days * @one_day_in_seconds, :second)

  @doc """
  Creates a new session.
  """
  @spec new_session(UserAccount.t(), ClientMetadata.t()) ::
          Changeset.t(__MODULE__.t())
  def new_session(user_account, client_metadata) do
    id = UUID.generate()
    now = DateTime.utc_now()

    client_ip_address =
      if client_metadata.ip_address,
        do: ClientMetadata.serialize_ip_address(client_metadata.ip_address),
        else: nil

    %__MODULE__{}
    |> change(
      id: id,
      token: generate_session_token(),
      client_ip_address: client_ip_address,
      client_user_agent: client_metadata.user_agent,
      user_account: user_account,
      user_account_id: user_account.id,
      created_at: now
    )
    |> validate_required([:id, :token, :user_account, :created_at])
    |> validate_length(:client_ip_address, max: 50)
  end

  @doc """
  Creates a query to find a session that has not yet expired by token.
  """
  @spec fetch_active_session_by_token(String.t()) ::
          {:ok, __MODULE__.t()} | {:error, :session_not_found}
  def fetch_active_session_by_token(token) do
    if session =
         Repo.one(
           from(us in __MODULE__,
             join: ua in UserAccount,
             on: us.user_account_id == ua.id,
             where: us.token == ^token and us.created_at > ago(@session_validity_in_days, "day"),
             preload: [user_account: ua]
           )
         ) do
      {:ok, session}
    else
      {:error, :session_not_found}
    end
  end

  @doc """
  Finds the session with the specified ID.
  """
  @spec fetch_by_id(String.t()) :: {:ok, __MODULE__.t()} | {:error, :session_not_found}
  def fetch_by_id(id),
    do:
      id
      |> uuid_or(:session_not_found)
      |> ok_then(&fetch_by_uuid/1)

  defp fetch_by_uuid(uuid),
    do:
      from(us in __MODULE__,
        join: ua in UserAccount,
        on: us.user_account_id == ua.id,
        preload: [user_account: ua]
      )
      |> Repo.get(uuid)
      |> truthy_or(:session_not_found)

  @doc """
  Find active sessions (that have not yet expired) by token.
  """
  @spec fetch_active_sessions_by_user_account_id(String.t()) :: list(__MODULE__.t())
  def fetch_active_sessions_by_user_account_id(id),
    do:
      Repo.all(
        from(us in __MODULE__,
          join: ua in UserAccount,
          on: us.user_account_id == ua.id,
          where: ua.id == ^id and us.created_at > ago(@session_validity_in_days, "day"),
          order_by: [desc: us.created_at],
          preload: [user_account: ua]
        )
      )

  @doc """
  Updates the date at which the specified session was last used.
  """
  @spec touch(__MODULE__.t(), ClientMetadata.t()) ::
          {:ok, __MODULE__.t()} | {:error, :session_not_found}
  def touch(session, client_metadata) do
    now = DateTime.utc_now()

    client_ip_address =
      if client_metadata.ip_address,
        do: ClientMetadata.serialize_ip_address(client_metadata.ip_address),
        else: nil

    updates = [
      used_at: now,
      client_ip_address: client_ip_address,
      client_user_agent: client_metadata.user_agent
    ]

    case Repo.update_all(query_session_by_id(session), set: updates) do
      {0, _result} ->
        {:error, :session_not_found}

      {n, _result} when n == 1 ->
        {:ok,
         %__MODULE__{
           session
           | used_at: now,
             client_ip_address: client_ip_address,
             client_user_agent: client_metadata.user_agent
         }}
    end
  end

  defp generate_session_token do
    time = System.os_time(:microsecond)
    random_bytes = :crypto.strong_rand_bytes(@session_token_bytes)

    <<time::64>> <> random_bytes
  end

  defp query_session_by_id(%__MODULE__{id: id}), do: from(us in __MODULE__, where: us.id == ^id)
end
