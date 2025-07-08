defmodule ArchiDep do
  @moduledoc """
  This module keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Returns the current version of the application.
  """
  @spec version() :: Version.t()
  def version do
    {:ok, vsn} = :application.get_key(:archidep, :vsn)
    vsn |> List.to_string() |> Version.parse!()
  end

  @spec behaviour :: Macro.t()
  def behaviour do
    quote do
      alias ArchiDep.Authentication
      alias Ecto.Changeset
      alias Ecto.UUID
    end
  end

  @spec context :: Macro.t()
  def context do
    quote do
      alias ArchiDep.Authentication
      alias Ecto.Changeset
      alias Ecto.UUID
    end
  end

  @spec event :: Macro.t()
  def event do
    quote do
      alias ArchiDep.Events.Store.Event
      alias Ecto.UUID
    end
  end

  @spec policy :: Macro.t()
  def policy do
    quote do
      alias Ecto.Changeset
      alias ArchiDep.Accounts.Schemas.UserAccount
      alias ArchiDep.Authentication
      alias ArchiDep.Policy

      @behaviour Policy
    end
  end

  @spec pub_sub :: Macro.t()
  def pub_sub do
    quote do
      import ArchiDep.Authorization
      alias ArchiDep.Authentication
      alias Ecto.UUID
      alias Phoenix.PubSub
    end
  end

  @spec schema :: Macro.t()
  def schema do
    quote do
      use Ecto.Schema

      import ArchiDep.Helpers.PipeHelpers
      import ArchiDep.Helpers.SchemaHelpers
      import Ecto.Changeset
      import Ecto.Query, only: [from: 2]
      alias ArchiDep.Repo
      alias Ecto.Association.NotLoaded
      alias Ecto.Changeset
      alias Ecto.Query
      alias Ecto.UUID
    end
  end

  @spec use_case :: Macro.t()
  def use_case do
    quote do
      import ArchiDep.Authentication, only: [has_role?: 2]
      import ArchiDep.Authorization
      import ArchiDep.Helpers.DataHelpers, only: [validate_uuid: 2]
      import ArchiDep.Helpers.PipeHelpers
      import ArchiDep.Helpers.UseCaseHelpers
      import ArchiDep.Repo, only: [transaction: 1]
      import Ecto.Multi, only: [delete: 3, insert: 3, put: 3, run: 3, update: 3]
      import Ecto.Query, only: [from: 2]
      alias ArchiDep.Accounts.Schemas.UserAccount
      alias ArchiDep.Authentication
      alias Ecto.Changeset
      alias Ecto.Multi
      alias Ecto.UUID
      alias ArchiDep.Authentication
      alias ArchiDep.Events.Store.StoredEvent
      alias ArchiDep.Repo
    end
  end

  @doc """
  When used, dispatch to the appropriate function.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
