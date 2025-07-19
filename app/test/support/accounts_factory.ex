defmodule ArchiDep.Support.AccountsFactory do
  @moduledoc """
  Test fixtures for the accounts context.
  """

  use ArchiDep.Support, :factory

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserAccount

  @roles [:root, :student]

  @spec user_account_factory(map()) :: UserAccount.t()
  def user_account_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {username, attrs!} =
      Map.pop_lazy(attrs!, :user_account_username, fn ->
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

  @spec roles() :: list(ArchiDep.Types.role())
  def roles, do: [role()]

  @spec role() :: ArchiDep.Types.role()
  def role, do: Enum.random(@roles)
end
