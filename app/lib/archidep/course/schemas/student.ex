defmodule ArchiDep.Course.Schemas.Student do
  @moduledoc """
  A student enrolled in a class, with a user account for accessing the course.
  Initially, only the student exists until that person logs in with the
  corresponding email, which automatically creates their user account.
  """

  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Course.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

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
          class: Class.t() | NotLoaded.t(),
          class_id: UUID.t(),
          user: User.t() | nil | NotLoaded.t(),
          user_id: UUID.t() | nil,
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "students" do
    field(:name, :string)
    field(:email, :string)
    field(:academic_class, :string)
    field(:username, :string)
    field(:username_confirmed, :boolean, default: false)
    field(:domain, :string)
    field(:active, :boolean, default: false)
    field(:servers_enabled, :boolean, default: false)
    belongs_to(:class, Class)
    belongs_to(:user, User, source: :user_account_id)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{active: active, class: %Class{} = class}, now),
    do: active and Class.active?(class, now)

  @spec can_create_servers?(t()) :: boolean
  @spec can_create_servers?(t(), DateTime.t()) :: boolean
  def can_create_servers?(
        %__MODULE__{servers_enabled: servers_enabled, class: class} = member,
        now \\ DateTime.utc_now()
      ),
      do:
        active?(member, now) and
          (servers_enabled or Class.allows_server_creation?(class, now))

  @spec list_students_in_class(UUID.t()) :: list(t())
  def list_students_in_class(class_id),
    do:
      Repo.all(
        from s in __MODULE__,
          join: c in assoc(s, :class),
          left_join: u in assoc(s, :user),
          left_join: us in assoc(u, :student),
          left_join: usc in assoc(us, :class),
          where: s.class_id == ^class_id,
          order_by: s.name,
          preload: [class: c, user: {u, student: {us, class: usc}}]
      )

  @spec fetch_student(UUID.t()) :: {:ok, t()} | {:error, :student_not_found}
  def fetch_student(id),
    do:
      from(s in __MODULE__,
        join: c in assoc(s, :class),
        left_join: u in assoc(s, :user),
        left_join: us in assoc(u, :student),
        left_join: usc in assoc(us, :class),
        where: s.id == ^id,
        preload: [class: c, user: {u, student: {us, class: usc}}]
      )
      |> Repo.one()
      |> truthy_or(:student_not_found)

  @spec fetch_student_for_user_account_id(UUID.t()) :: {:ok, t()} | {:error, :student_not_found}
  def fetch_student_for_user_account_id(id),
    do:
      from(s in __MODULE__,
        join: c in assoc(s, :class),
        left_join: cesp in assoc(c, :expected_server_properties),
        join: u in assoc(s, :user),
        where: u.id == ^id and u.student_id == s.id,
        preload: [class: {c, expected_server_properties: cesp}, user: u]
      )
      |> Repo.one()
      |> truthy_or(:student_not_found)

  @spec fetch_student_in_class(UUID.t(), UUID.t()) :: {:ok, t()} | {:error, :student_not_found}
  def fetch_student_in_class(class_id, id),
    do:
      from(s in __MODULE__,
        where: s.class_id == ^class_id and s.id == ^id,
        join: c in assoc(s, :class),
        left_join: u in assoc(s, :user),
        left_join: us in assoc(u, :student),
        left_join: usc in assoc(us, :class),
        preload: [class: c, user: {u, student: {us, class: usc}}]
      )
      |> Repo.one()
      |> truthy_or(:student_not_found)

  @spec refresh!(t(), map()) :: t()
  def refresh!(
        %__MODULE__{
          id: id,
          class: %Class{id: class_id, version: class_version},
          user: %User{id: user_id, version: user_version},
          version: current_version
        } = student,
        %__MODULE__{
          id: id,
          name: name,
          email: email,
          academic_class: academic_class,
          username: username,
          username_confirmed: username_confirmed,
          domain: domain,
          active: active,
          servers_enabled: servers_enabled,
          class: %Class{id: class_id, version: class_version},
          user: %User{id: user_id, version: user_version},
          version: version,
          updated_at: updated_at
        }
      )
      when version == current_version + 1 do
    %__MODULE__{
      student
      | name: name,
        email: email,
        academic_class: academic_class,
        username: username,
        username_confirmed: username_confirmed,
        domain: domain,
        active: active,
        servers_enabled: servers_enabled,
        version: version,
        updated_at: updated_at
    }
  end

  def refresh!(
        %__MODULE__{
          id: id,
          class: %Class{id: class_id, version: class_version},
          user: %User{id: user_id, version: user_version},
          version: current_version
        } = student,
        %{
          id: id,
          name: name,
          username: username,
          domain: domain,
          active: active,
          servers_enabled: servers_enabled,
          group: %{id: class_id, version: class_version},
          owner: %{id: user_id, version: user_version},
          version: version,
          updated_at: updated_at
        }
      )
      when version == current_version + 1 do
    %__MODULE__{
      student
      | name: name,
        username: username,
        domain: domain,
        active: active,
        servers_enabled: servers_enabled,
        version: version,
        updated_at: updated_at
    }
  end

  def refresh!(%__MODULE__{id: id, version: current_version} = student, %{
        id: id,
        version: version
      })
      when version <= current_version do
    student
  end

  def refresh!(%__MODULE__{id: id}, %{id: id}) do
    {:ok, fresh_student} = fetch_student(id)
    fresh_student
  end

  @spec new(Types.create_student_data()) :: Changeset.t(t())
  def new(data) do
    id = UUID.generate()
    class_id = data.class_id
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(data, [
      :name,
      :email,
      :academic_class,
      :username,
      :domain,
      :active,
      :servers_enabled,
      :class_id
    ])
    |> change(
      id: id,
      username_confirmed: false,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate(id, class_id)
  end

  @spec update(t(), Types.existing_student_data()) :: Changeset.t(t())
  def update(student, data) do
    id = student.id
    class_id = student.class_id
    now = DateTime.utc_now()

    student
    |> cast(data, [
      :name,
      :email,
      :academic_class,
      :username,
      :domain,
      :active,
      :servers_enabled
    ])
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> validate(id, class_id)
  end

  @spec configure_changeset(t(), Types.student_config()) :: Changeset.t()
  def configure_changeset(%__MODULE__{} = student, data) do
    now = DateTime.utc_now()

    student
    |> cast(data, [:username])
    |> change(username_confirmed: true)
    |> validate_required([:username])
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    # Username
    |> update_change(:username, &trim/1)
    |> validate_length(:username, max: 20, message: "must be at most {count} characters long")
    |> validate_format(:username, ~r/\A[a-z][\-a-z0-9]*\z/i,
      message:
        "must contain only letters (without accents), numbers and hyphens, and start with a letter"
    )
    |> unique_constraint(:username, name: :students_username_unique)
    |> unsafe_validate_username_unique(student.id, student.class_id)
  end

  defp validate(changeset, _id, nil), do: validate(changeset)

  defp validate(changeset, id, class_id),
    do:
      changeset
      |> validate()
      |> unsafe_validate_email_unique(id, class_id)
      |> unsafe_validate_username_unique(id, class_id)

  defp validate(changeset),
    do:
      changeset
      |> update_change(:name, &trim/1)
      |> update_change(:email, &trim/1)
      |> update_change(:academic_class, &trim_to_nil/1)
      |> update_change(:username, &trim/1)
      |> update_change(:domain, &trim/1)
      |> validate_required([
        :name,
        :email,
        :username,
        :username_confirmed,
        :domain,
        :active,
        :servers_enabled,
        :class_id
      ])
      # Name
      |> validate_length(:name, max: 200)
      # Email
      |> validate_length(:email, max: 255)
      |> validate_format(:email, ~r/\A.+@.+\..+\z/, message: "must be a valid email address")
      |> unique_constraint(:email, name: :students_unique_email_index)
      # Academic class
      |> validate_length(:academic_class, max: 30)
      # Username
      |> validate_length(:username, max: 20)
      |> validate_format(:username, ~r/\A[a-z][a-z0-9]*\z/i,
        message:
          "must contain only letters (without accents), numbers and hyphens, and start with a letter"
      )
      |> unique_constraint(:username, name: :students_username_unique)
      # Domain
      |> validate_length(:domain, max: 20)
      |> validate_format(:domain, ~r/\A[a-z0-9][\-a-z0-9]*(?:\.[a-z][\-a-z0-9]*)+\z/i,
        message:
          "must be a valid domain name containing only letters (without accents), numbers and hyphens"
      )
      # Class
      |> assoc_constraint(:class)

  defp unsafe_validate_email_unique(changeset, id, class_id),
    do:
      unsafe_validate_unique_query(changeset, :email, Repo, fn changeset ->
        email = get_field(changeset, :email)

        from(s in __MODULE__,
          where:
            s.id != ^id and s.class_id == ^class_id and
              fragment("LOWER(?)", s.email) == fragment("LOWER(?)", ^email)
        )
      end)

  defp unsafe_validate_username_unique(changeset, id, class_id),
    do:
      unsafe_validate_unique_query(changeset, :username, Repo, fn changeset ->
        username = get_field(changeset, :username)

        from(s in __MODULE__,
          where:
            s.id != ^id and s.class_id == ^class_id and
              fragment("LOWER(?)", s.username) == fragment("LOWER(?)", ^username)
        )
      end)
end
