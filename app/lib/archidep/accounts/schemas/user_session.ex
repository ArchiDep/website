defmodule ArchiDep.Accounts.Schemas.UserSession do
  @moduledoc """
  A session representing the fact that a user is logged in with a browser. The
  session remains active until it either expires or is deleted by the user or an
  administrator.
  """

  use ArchiDep, :schema

  import ArchiDep.Accounts.Schemas.UserAccount, only: [where_user_account_active: 1]
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Authentication
  alias ArchiDep.ClientMetadata

  @derive {Inspect, only: [:id, :created_at, :user_account]}
  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @session_token_bytes 50
  @session_validity_in_days 30
  @one_day_in_seconds 24 * 60 * 60

  @type t :: %__MODULE__{
          id: UUID.t(),
          token: String.t(),
          created_at: DateTime.t(),
          used_at: DateTime.t() | nil,
          client_ip_address: String.t() | nil,
          client_user_agent: String.t() | nil,
          user_account: UserAccount.t() | NotLoaded.t(),
          user_account_id: UUID.t(),
          impersonated_user_account: UserAccount.t() | nil | NotLoaded.t(),
          impersonated_user_account_id: UUID.t() | nil
        }

  schema "user_sessions" do
    field(:token, :binary, redact: true)
    field(:created_at, :utc_datetime_usec)
    field(:used_at, :utc_datetime_usec)
    field(:client_ip_address, :string)
    field(:client_user_agent, :string)
    belongs_to(:user_account, UserAccount)
    belongs_to(:impersonated_user_account, UserAccount, on_replace: :nilify)
  end

  @spec authentication(t()) :: Authentication.t()
  def authentication(%__MODULE__{
        id: id,
        token: token,
        created_at: created_at,
        user_account: user_account,
        impersonated_user_account: impersonated_user_account,
        impersonated_user_account_id: impersonated_user_account_id
      }) do
    principal = impersonated_user_account || user_account

    session_expires_at =
      DateTime.add(created_at, @session_validity_in_days * @one_day_in_seconds, :second)

    %Authentication{
      principal_id: principal.id,
      username: principal.username,
      roles: principal.roles,
      session_id: id,
      session_token: token,
      session_expires_at: session_expires_at,
      impersonated_id: impersonated_user_account_id
    }
  end

  @spec current_session?(t(), Authentication.t()) :: boolean
  def current_session?(%__MODULE__{id: session_id}, %Authentication{session_id: session_id}),
    do: true

  def current_session?(%__MODULE__{}, %Authentication{}), do: false

  @spec expires_at(t()) :: DateTime.t()
  def expires_at(%__MODULE__{created_at: created_at}),
    do: DateTime.add(created_at, @session_validity_in_days * @one_day_in_seconds, :second)

  @spec new_session(UserAccount.t(), ClientMetadata.t()) ::
          Changeset.t(t())
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

  @spec fetch_active_session_by_id(UUID.t(), DateTime.t()) ::
          {:ok, t()} | {:error, :session_not_found}
  def fetch_active_session_by_id(id, now) do
    where =
      dynamic(
        [user_session: us],
        us.id == ^id and us.created_at > ago(@session_validity_in_days, "day") and
          ^where_user_account_active(now)
      )

    if session =
         Repo.one(
           from(us in __MODULE__,
             as: :user_session,
             join: ua in assoc(us, :user_account),
             as: :user_account,
             left_join: pu in assoc(ua, :preregistered_user),
             as: :preregistered_user,
             left_join: ug in assoc(pu, :group),
             as: :user_group,
             left_join: iua in assoc(us, :impersonated_user_account),
             left_join: iuapu in assoc(iua, :preregistered_user),
             left_join: iuag in assoc(iuapu, :group),
             where: ^where,
             preload: [
               user_account: {ua, preregistered_user: {pu, group: ug}},
               impersonated_user_account: {iua, preregistered_user: {iuapu, group: iuag}}
             ]
           )
         ) do
      {:ok, session}
    else
      {:error, :session_not_found}
    end
  end

  @spec fetch_active_session_by_token(String.t(), DateTime.t()) ::
          {:ok, t()} | {:error, :session_not_found}
  def fetch_active_session_by_token(token, now) do
    where =
      dynamic(
        [user_session: us],
        us.token == ^token and us.created_at > ago(@session_validity_in_days, "day") and
          ^where_user_account_active(now)
      )

    if session =
         Repo.one(
           from(us in __MODULE__,
             as: :user_session,
             join: ua in assoc(us, :user_account),
             as: :user_account,
             left_join: pu in assoc(ua, :preregistered_user),
             as: :preregistered_user,
             left_join: ug in assoc(pu, :group),
             as: :user_group,
             left_join: iua in assoc(us, :impersonated_user_account),
             left_join: iuapu in assoc(iua, :preregistered_user),
             left_join: iuag in assoc(iuapu, :group),
             where: ^where,
             preload: [
               user_account: {ua, preregistered_user: {pu, group: ug}},
               impersonated_user_account: {iua, preregistered_user: {iuapu, group: iuag}}
             ]
           )
         ) do
      {:ok, session}
    else
      {:error, :session_not_found}
    end
  end

  @spec fetch_by_id(String.t()) :: {:ok, t()} | {:error, :session_not_found}
  def fetch_by_id(id),
    do:
      id
      |> uuid_or(:session_not_found)
      |> ok_then(&fetch_by_uuid/1)

  defp fetch_by_uuid(uuid),
    do:
      from(us in __MODULE__,
        join: ua in assoc(us, :user_account),
        left_join: iua in assoc(us, :impersonated_user_account),
        preload: [user_account: ua, impersonated_user_account: iua]
      )
      |> Repo.get(uuid)
      |> truthy_or(:session_not_found)

  @spec fetch_active_sessions_by_user_account_id(String.t()) :: list(t())
  def fetch_active_sessions_by_user_account_id(id),
    do:
      Repo.all(
        from(us in __MODULE__,
          join: ua in assoc(us, :user_account),
          where: ua.id == ^id and us.created_at > ago(@session_validity_in_days, "day"),
          order_by: [desc: us.created_at],
          preload: [user_account: ua]
        )
      )

  @spec touch(t(), ClientMetadata.t()) ::
          {:ok, t()} | {:error, :session_not_found}
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

  @spec impersonate(t(), UserAccount.t()) :: t()
  def impersonate(
        %__MODULE__{user_account_id: current_user_account_id, impersonated_user_account_id: nil} =
          session,
        %UserAccount{id: user_account_id} = user_account
      )
      when current_user_account_id != user_account_id,
      do:
        session
        |> change(
          impersonated_user_account: user_account,
          impersonated_user_account_id: user_account.id
        )
        |> Repo.update!()

  @spec stop_impersonating(t()) :: t()

  def stop_impersonating(%__MODULE__{impersonated_user_account_id: nil} = session),
    do: session

  def stop_impersonating(
        %__MODULE__{} =
          session
      ) do
    session
    |> change(
      impersonated_user_account: nil,
      impersonated_user_account_id: nil
    )
    |> Repo.update!()
  end

  defp generate_session_token do
    time = System.os_time(:microsecond)
    random_bytes = :crypto.strong_rand_bytes(@session_token_bytes)

    <<time::64>> <> random_bytes
  end

  defp query_session_by_id(%__MODULE__{id: id}), do: from(us in __MODULE__, where: us.id == ^id)
end
