defmodule ArchiDep.Course.StudentView do
  @moduledoc """
  Curated read model of a student for the web layer. It is the persistence
  aggregate (`ArchiDep.Course.Schemas.Student`) projected into a plain struct,
  with the nested `class` / `user` reusing the existing schema read-views.

  `refresh!/3` applies a curated domain event to the in-memory projection: a
  student event updates the student-level fields (and, for an account linkage,
  the nested `user`), and a class event refreshes the nested `class`, so a
  single call keeps the whole projection current regardless of which source
  aggregate changed.
  """

  import ArchiDep.Helpers.SchemaHelpers
  alias ArchiDep.Accounts.Events.PreregisteredUserLinkedToUserAccount
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Events.StudentConfigured
  alias ArchiDep.Course.Events.StudentUpdated
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Events.Store.EventReference
  alias Ecto.UUID

  @enforce_keys [
    :id,
    :name,
    :email,
    :academic_class,
    :username,
    :username_confirmed,
    :domain,
    :active,
    :servers_enabled,
    :ssh_exercise_password,
    :class,
    :class_id,
    :user,
    :user_id,
    :version,
    :created_at,
    :updated_at
  ]
  defstruct [
    :id,
    :name,
    :email,
    :academic_class,
    :username,
    :username_confirmed,
    :domain,
    :active,
    :servers_enabled,
    :ssh_exercise_password,
    :class,
    :class_id,
    :user,
    :user_id,
    :version,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil,
          username: String.t(),
          username_confirmed: boolean(),
          domain: String.t(),
          active: boolean(),
          servers_enabled: boolean(),
          ssh_exercise_password: String.t(),
          class: ClassView.t(),
          class_id: UUID.t(),
          user: User.t() | nil,
          user_id: UUID.t() | nil,
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @student_events [StudentUpdated, StudentConfigured, PreregisteredUserLinkedToUserAccount]
  @class_events [ClassUpdated, ClassExpectedServerPropertiesUpdated]

  @doc """
  Builds a curated `StudentView` from a fully-loaded student aggregate, reusing
  the nested `class` / `user` read-views unchanged.
  """
  @spec from(Student.t()) :: t()
  def from(%Student{} = student),
    do: %__MODULE__{
      id: student.id,
      name: student.name,
      email: student.email,
      academic_class: student.academic_class,
      username: student.username,
      username_confirmed: student.username_confirmed,
      domain: student.domain,
      active: student.active,
      servers_enabled: student.servers_enabled,
      ssh_exercise_password: student.ssh_exercise_password,
      class: ClassView.from(student.class),
      class_id: student.class_id,
      user: student.user,
      user_id: student.user_id,
      version: student.version,
      created_at: student.created_at,
      updated_at: student.updated_at
    }

  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{active: active, class: %ClassView{} = class}, now),
    do: active and ClassView.active?(class, now)

  @spec can_create_servers?(t()) :: boolean
  @spec can_create_servers?(t(), DateTime.t()) :: boolean
  def can_create_servers?(
        %__MODULE__{servers_enabled: servers_enabled, class: class} = student,
        now \\ DateTime.utc_now()
      ),
      do:
        active?(student, now) and
          (servers_enabled or ClassView.allows_server_creation?(class, now))

  @spec refresh!(
          t(),
          StudentUpdated.t()
          | StudentConfigured.t()
          | PreregisteredUserLinkedToUserAccount.t()
          | ClassUpdated.t()
          | ClassExpectedServerPropertiesUpdated.t(),
          EventReference.t()
        ) :: t()
  def refresh!(
        %__MODULE__{} = view,
        %event_module{} = event,
        %EventReference{version: version, occurred_at: occurred_at}
      )
      when event_module in @student_events,
      do:
        versioned_refresh(
          view,
          event,
          version,
          &fetch/1,
          &merge_student(&1, &2, version, occurred_at)
        )

  def refresh!(
        %__MODULE__{class: %ClassView{} = class} = view,
        %event_module{} = event,
        %EventReference{} = reference
      )
      when event_module in @class_events,
      do: %__MODULE__{view | class: ClassView.refresh!(class, event, reference)}

  defp fetch(id) do
    case Student.fetch_student(id) do
      {:ok, student} -> {:ok, from(student)}
      {:error, _reason} = error -> error
    end
  end

  defp merge_student(
         %__MODULE__{id: id} = view,
         %StudentUpdated{
           id: id,
           name: name,
           email: email,
           academic_class: academic_class,
           username: username,
           domain: domain,
           active: active,
           servers_enabled: servers_enabled
         },
         version,
         updated_at
       ),
       do: %__MODULE__{
         view
         | name: name,
           email: email,
           academic_class: academic_class,
           username: username,
           domain: domain,
           active: active,
           servers_enabled: servers_enabled,
           version: version,
           updated_at: updated_at
       }

  defp merge_student(
         %__MODULE__{id: id} = view,
         %StudentConfigured{id: id, username: username},
         version,
         updated_at
       ),
       do: %__MODULE__{
         view
         | username: username,
           username_confirmed: true,
           version: version,
           updated_at: updated_at
       }

  defp merge_student(
         %__MODULE__{id: id} = view,
         %PreregisteredUserLinkedToUserAccount{
           preregistered_user_id: id,
           user_account: %{
             id: user_account_id,
             username: username,
             active: active,
             version: user_version
           }
         },
         version,
         updated_at
       ),
       do: %__MODULE__{
         view
         | user_id: user_account_id,
           user: %User{
             id: user_account_id,
             username: username,
             active: active,
             student_id: id,
             version: user_version,
             created_at: updated_at,
             updated_at: updated_at
           },
           version: version,
           updated_at: updated_at
       }

  defp merge_student(_view, _incoming, _version, _updated_at), do: :refetch
end
