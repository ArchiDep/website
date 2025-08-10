defmodule ArchiDep.Course.Schemas.Class do
  @moduledoc """
  A group of students participating in a specific instance of the course (e.g.
  the course for the 2024-2025 academic year).
  """

  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Course.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          servers_enabled: boolean(),
          expected_server_properties: ExpectedServerProperties.t() | NotLoaded.t(),
          expected_server_properties_id: UUID.t(),
          # Common metadata
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "classes" do
    field(:name, :binary)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:active, :boolean)
    field(:servers_enabled, :boolean, default: false)
    belongs_to(:expected_server_properties, ExpectedServerProperties, on_replace: :update)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec allows_server_creation?(t(), DateTime.t()) :: boolean()
  def allows_server_creation?(%__MODULE__{servers_enabled: servers_enabled} = class, now),
    do: servers_enabled and active?(class, now)

  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{active: active, start_date: start_date, end_date: end_date}, now),
    do:
      active and
        (is_nil(start_date) or now |> DateTime.to_date() |> Date.compare(start_date) != :lt) and
        (is_nil(end_date) or now |> DateTime.to_date() |> Date.compare(end_date) != :gt)

  @spec list_classes() :: list(t())
  def list_classes,
    do:
      Repo.all(
        from c in __MODULE__,
          join: esp in assoc(c, :expected_server_properties),
          order_by: [desc: c.active, desc: c.end_date, desc: c.created_at, asc: c.name],
          preload: [expected_server_properties: esp]
      )

  @spec list_active_classes(Date.t()) :: list(t())
  def list_active_classes(day),
    do:
      Repo.all(
        from c in __MODULE__,
          where:
            c.active == true and (is_nil(c.start_date) or c.start_date <= ^day) and
              (is_nil(c.end_date) or c.end_date >= ^day),
          join: esp in assoc(c, :expected_server_properties),
          order_by: [desc: c.end_date, desc: c.created_at, asc: c.name],
          preload: [expected_server_properties: esp]
      )

  @spec fetch_class(UUID.t()) :: {:ok, t()} | {:error, :class_not_found}
  def fetch_class(id),
    do:
      from(c in __MODULE__,
        join: esp in assoc(c, :expected_server_properties),
        where: c.id == ^id,
        preload: [expected_server_properties: esp]
      )
      |> Repo.one()
      |> truthy_or(:class_not_found)

  @spec new(Types.class_data()) :: Changeset.t(t())
  def new(data) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(data, [
      :name,
      :start_date,
      :end_date,
      :active,
      :servers_enabled
    ])
    |> change(
      id: id,
      expected_server_properties: ExpectedServerProperties.blank(id),
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate()
    |> unsafe_validate_unique_query(:name, Repo, fn changeset ->
      name = get_field(changeset, :name)

      from(c in __MODULE__,
        where: fragment("LOWER(?)", c.name) == fragment("LOWER(?)", ^name)
      )
    end)
  end

  @spec update(t(), Types.class_data()) :: Changeset.t(t())
  def update(class, data) do
    id = class.id
    now = DateTime.utc_now()

    class
    |> cast(data, [
      :name,
      :start_date,
      :end_date,
      :active,
      :servers_enabled
    ])
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> validate()
    |> unsafe_validate_unique_query(:name, Repo, fn changeset ->
      name = get_field(changeset, :name)

      from(c in __MODULE__,
        where: c.id != ^id and fragment("LOWER(?)", c.name) == fragment("LOWER(?)", ^name)
      )
    end)
  end

  @spec update_expected_server_properties(t(), Types.expected_server_properties()) ::
          Changeset.t(t())
  def update_expected_server_properties(class, data) do
    now = DateTime.utc_now()

    class
    |> cast(
      %{
        expected_server_properties: data
      },
      []
    )
    |> cast_assoc(:expected_server_properties,
      with: &ExpectedServerProperties.update/2
    )
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> validate_required([:expected_server_properties])
  end

  @spec refresh!(t(), map()) :: t()
  def refresh!(
        %__MODULE__{
          id: id,
          expected_server_properties: expected_server_properties,
          version: current_version
        } = class,
        %{
          id: id,
          name: name,
          start_date: start_date,
          end_date: end_date,
          active: active,
          servers_enabled: servers_enabled,
          expected_server_properties: new_expected_server_properties,
          version: version,
          updated_at: updated_at
        }
      )
      when version == current_version + 1 do
    %__MODULE__{
      class
      | name: name,
        start_date: start_date,
        end_date: end_date,
        active: active,
        servers_enabled: servers_enabled,
        expected_server_properties:
          ExpectedServerProperties.refresh(
            expected_server_properties,
            new_expected_server_properties
          ),
        version: version,
        updated_at: updated_at
    }
  end

  def refresh!(%__MODULE__{id: id, version: current_version} = class, %{
        id: id,
        version: version
      })
      when version <= current_version do
    class
  end

  def refresh!(%__MODULE__{id: id}, %{id: id}) do
    {:ok, fresh_class} = fetch_class(id)
    fresh_class
  end

  @spec delete(t()) :: Changeset.t(t())
  def delete(class) do
    class
    |> change()
    |> foreign_key_constraint(:servers,
      name: :servers_class_id_fkey,
      message: "class has servers"
    )
  end

  defp validate(changeset) do
    changeset
    |> update_change(:name, &trim/1)
    |> validate_required([:name, :active, :servers_enabled])
    |> validate_length(:name, max: 50)
    |> unique_constraint(:name, name: :classes_unique_name_index)
    |> validate_start_and_end_dates()
  end

  defp validate_start_and_end_dates(changeset) do
    if changed?(changeset, :start_date) or changed?(changeset, :end_date) do
      validate_start_and_end_dates(
        changeset,
        get_field(changeset, :start_date),
        get_field(changeset, :end_date)
      )
    else
      changeset
    end
  end

  defp validate_start_and_end_dates(changeset, nil, _end_date) do
    changeset
  end

  defp validate_start_and_end_dates(changeset, _start_date, nil) do
    changeset
  end

  defp validate_start_and_end_dates(changeset, start_date, end_date) do
    if Date.compare(start_date, end_date) == :gt do
      add_error(changeset, :end_date, "must be after the start date")
    else
      changeset
    end
  end
end
