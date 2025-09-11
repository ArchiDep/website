defmodule ArchiDep do
  @moduledoc """
  ArchiDep is an application for an Architecture & Deployment system
  administration course, allowing teachers to manage classes and students, and
  students to follow the course and register their own servers (typically
  virtual machines hosted in a cloud) for exercises.
  """

  @spec version() :: Version.t()
  def version do
    {:ok, vsn} = :application.get_key(:archidep, :vsn)
    vsn |> List.to_string() |> Version.parse!()
  end

  @spec context :: Macro.t()
  def context do
    quote do
      import ArchiDep.Helpers.ContextHelpers, only: [delegate: 1]
      alias ArchiDep.Authentication
      alias Ecto.Changeset
      alias Ecto.UUID
    end
  end

  @spec context_behaviour :: Macro.t()
  def context_behaviour do
    quote do
      use ArchiDep.Helpers.ContextHelpers, :behaviour

      import ArchiDep.Helpers.ContextHelpers, only: [callback: 1]
      alias ArchiDep.Authentication
      alias ArchiDep.Events.Store.EventReference
      alias Ecto.Changeset
      alias Ecto.UUID
    end
  end

  @spec context_impl :: Macro.t()
  def context_impl do
    quote do
      import ArchiDep.Helpers.ContextHelpers, only: [implement: 2]
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
      alias ArchiDep.Accounts.Schemas.UserAccount
      alias ArchiDep.Authentication
      alias ArchiDep.Policy
      alias Ecto.Changeset

      @behaviour Policy
    end
  end

  @spec pub_sub :: Macro.t()
  def pub_sub do
    quote do
      import ArchiDep.Helpers.AuthHelpers
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
      import Ecto.Query, only: [dynamic: 2, from: 2]
      alias ArchiDep.Events.Store.EventReference
      alias ArchiDep.Repo
      alias Ecto.Association.NotLoaded
      alias Ecto.Changeset
      alias Ecto.Multi
      alias Ecto.Query
      alias Ecto.Queryable
      alias Ecto.UUID
    end
  end

  @spec use_case :: Macro.t()
  def use_case do
    quote do
      import ArchiDep.Authentication, only: [root?: 1]
      import ArchiDep.Helpers.AuthHelpers
      import ArchiDep.Helpers.DataHelpers, only: [validate_uuid: 2]
      import ArchiDep.Helpers.PipeHelpers
      import ArchiDep.Helpers.UseCaseHelpers
      import ArchiDep.Repo, only: [transaction: 1]
      import Ecto.Multi, only: [delete: 3, insert: 3, put: 3, run: 3, update: 3]
      import Ecto.Query, only: [from: 2]
      alias ArchiDep.Accounts.Schemas.UserAccount
      alias ArchiDep.Authentication
      alias ArchiDep.Authentication
      alias ArchiDep.Events.Store.EventReference
      alias ArchiDep.Events.Store.StoredEvent
      alias ArchiDep.Repo
      alias Ecto.Changeset
      alias Ecto.Multi
      alias Ecto.UUID
    end
  end

  @doc """
  When used, dispatch to the appropriate function.
  """
  @spec __using__(atom()) :: Macro.t()
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
