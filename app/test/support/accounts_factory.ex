defmodule ArchiDep.Support.AccountsFactory do
  @moduledoc """
  Test fixtures for the accounts context.
  """

  use ArchiDep.Support, :factory

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Accounts.Types
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.NetFactory

  @roles [:root, :student]

  @spec client_ip_address() :: String.t()
  def client_ip_address, do: NetFactory.ip_address() |> :inet.ntoa() |> List.to_string()

  @spec client_user_agent() :: String.t()
  defdelegate client_user_agent, to: Factory, as: :user_agent

  @spec current_session_factory(map()) :: UserSession.t()
  def current_session_factory(attrs) do
    attrs_with_defaults =
      Map.merge(
        %{
          created_at: Faker.DateTime.backward(30),
          used_at: DateTime.utc_now(),
          client_user_agent: Factory.user_agent(),
          impersonated_user_account: nil
        },
        attrs
      )

    user_session_factory(attrs_with_defaults)
  end

  @spec switch_edu_id_data_factory(map()) :: Types.switch_edu_id_data()
  def switch_edu_id_data_factory(attrs!) do
    {email, attrs!} = Map.pop_lazy(attrs!, :email, &Faker.Internet.email/0)

    {first_name, attrs!} =
      Map.pop_lazy(attrs!, :first_name, fn ->
        if(bool(), do: Faker.Person.first_name(), else: nil)
      end)

    {last_name, attrs!} =
      Map.pop_lazy(attrs!, :last_name, fn ->
        if(bool(), do: Faker.Person.last_name(), else: nil)
      end)

    {swiss_edu_person_unique_id, attrs!} =
      Map.pop_lazy(attrs!, :swiss_edu_person_unique_id, &Faker.String.base64/0)

    [] = Map.keys(attrs!)

    %{
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id
    }
  end

  @spec switch_edu_id_factory(map()) :: SwitchEduId.t()
  def switch_edu_id_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)
    {email, attrs!} = Map.pop_lazy(attrs!, :email, &Faker.Internet.email/0)

    {first_name, attrs!} =
      Map.pop_lazy(attrs!, :first_name, fn ->
        if(bool(), do: Faker.Person.first_name(), else: nil)
      end)

    {last_name, attrs!} =
      Map.pop_lazy(attrs!, :last_name, fn ->
        if(bool(), do: Faker.Person.last_name(), else: nil)
      end)

    {swiss_edu_person_unique_id, attrs!} =
      Map.pop_lazy(attrs!, :swiss_edu_person_unique_id, &Faker.String.base64/0)

    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!)

    {used_at, attrs!} =
      Map.pop_lazy(attrs!, :used_at, fn ->
        Faker.DateTime.between(created_at, DateTime.utc_now())
      end)

    [] = Map.keys(attrs!)

    %SwitchEduId{
      id: id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      swiss_edu_person_unique_id: swiss_edu_person_unique_id,
      version: version,
      created_at: created_at,
      updated_at: updated_at,
      used_at: used_at
    }
  end

  @spec user_account_factory(map()) :: UserAccount.t()
  def user_account_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {username, attrs!} =
      Map.pop_lazy(attrs!, :username, fn ->
        sequence(:user_account_username, &"user-account-#{&1}")
      end)

    {roles, attrs!} = Map.pop_lazy(attrs!, :roles, &roles/0)
    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)

    {switch_edu_id, attrs!} =
      Map.pop_lazy(attrs!, :switch_edu_id, fn -> build(:switch_edu_id) end)

    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!)

    [] = Map.keys(attrs!)

    %UserAccount{
      id: id,
      username: username,
      roles: roles,
      active: active,
      switch_edu_id: switch_edu_id,
      switch_edu_id_id: switch_edu_id.id,
      preregistered_user: nil,
      preregistered_user_id: nil,
      version: version,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  @spec user_session_factory(map()) :: UserSession.t()
  def user_session_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {token, attrs!} =
      Map.pop_lazy(attrs!, :token, fn ->
        sequence(:user_session_token, &"user-session-token-#{&1}")
      end)

    {created_at, attrs!} = pop_entity_created_at(attrs!)

    {used_at, attrs!} =
      Map.pop_lazy(
        attrs!,
        :used_at,
        optionally(fn -> Faker.DateTime.between(created_at, DateTime.utc_now()) end)
      )

    {client_ip_address, attrs!} =
      Map.pop_lazy(attrs!, :client_ip_address, optionally(&client_ip_address/0))

    {client_user_agent, attrs!} =
      Map.pop_lazy(attrs!, :client_user_agent, optionally(&client_user_agent/0))

    {user_account, attrs!} =
      Map.pop_lazy(attrs!, :user_account, fn -> build(:user_account) end)

    {user_account_id, attrs!} =
      Map.pop_lazy(attrs!, :user_account_id, fn ->
        case user_account do
          %UserAccount{} -> user_account.id
          %NotLoaded{} -> UUID.generate()
        end
      end)

    {impersonated_user_account, attrs!} =
      Map.pop_lazy(attrs!, :impersonated_user_account, fn -> build(:user_account) end)

    {impersonated_user_account_id, attrs!} =
      Map.pop_lazy(attrs!, :impersonated_user_account_id, fn ->
        case impersonated_user_account do
          nil -> nil
          %UserAccount{} -> impersonated_user_account.id
          %NotLoaded{} -> UUID.generate()
        end
      end)

    [] = Map.keys(attrs!)

    %UserSession{
      id: id,
      token: token,
      created_at: created_at,
      used_at: used_at,
      client_ip_address: client_ip_address,
      client_user_agent: client_user_agent,
      user_account: user_account,
      user_account_id: user_account_id,
      impersonated_user_account: impersonated_user_account,
      impersonated_user_account_id: impersonated_user_account_id
    }
  end

  @spec roles() :: list(ArchiDep.Types.role())
  def roles, do: [role()]

  @spec role() :: ArchiDep.Types.role()
  def role, do: Enum.random(@roles)
end
