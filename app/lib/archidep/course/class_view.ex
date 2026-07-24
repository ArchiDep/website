defmodule ArchiDep.Course.ClassView do
  @moduledoc """
  Curated read model of a class for the web layer. It is the persistence
  aggregate (`ArchiDep.Course.Schemas.Class`) projected into a plain struct,
  reusing the nested `expected_server_properties` schema read-view unchanged.

  `refresh!/3` applies a curated domain event to the in-memory projection: a
  `ClassUpdated` refreshes the class-level fields, and a
  `ClassExpectedServerPropertiesUpdated` refreshes the nested expected server
  properties, so a single call keeps the whole projection current.
  """

  import ArchiDep.Helpers.SchemaHelpers
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Events.Store.EventReference
  alias Ecto.Association.NotLoaded
  alias Ecto.UUID

  @enforce_keys [
    :id,
    :name,
    :start_date,
    :end_date,
    :active,
    :servers_enabled,
    :teacher_ssh_public_keys,
    :ssh_exercise_vm_md5_host_key_fingerprints,
    :ssh_exercise_vm_sha256_host_key_fingerprints,
    :expected_server_properties,
    :expected_server_properties_id,
    :version,
    :created_at,
    :updated_at
  ]
  defstruct [
    :id,
    :name,
    :start_date,
    :end_date,
    :active,
    :servers_enabled,
    :teacher_ssh_public_keys,
    :ssh_exercise_vm_md5_host_key_fingerprints,
    :ssh_exercise_vm_sha256_host_key_fingerprints,
    :expected_server_properties,
    :expected_server_properties_id,
    :version,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          servers_enabled: boolean(),
          teacher_ssh_public_keys: list(String.t()),
          ssh_exercise_vm_md5_host_key_fingerprints: String.t() | nil,
          ssh_exercise_vm_sha256_host_key_fingerprints: String.t() | nil,
          expected_server_properties: ExpectedServerProperties.t() | NotLoaded.t(),
          expected_server_properties_id: UUID.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @class_events [ClassUpdated, ClassExpectedServerPropertiesUpdated]

  @doc """
  Builds a curated `ClassView` from a fully-loaded class aggregate, reusing the
  nested `expected_server_properties` read-view unchanged.
  """
  @spec from(Class.t()) :: t()
  def from(%Class{} = class),
    do: %__MODULE__{
      id: class.id,
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      servers_enabled: class.servers_enabled,
      teacher_ssh_public_keys: class.teacher_ssh_public_keys,
      ssh_exercise_vm_md5_host_key_fingerprints: class.ssh_exercise_vm_md5_host_key_fingerprints,
      ssh_exercise_vm_sha256_host_key_fingerprints:
        class.ssh_exercise_vm_sha256_host_key_fingerprints,
      expected_server_properties: class.expected_server_properties,
      expected_server_properties_id: class.expected_server_properties_id,
      version: class.version,
      created_at: class.created_at,
      updated_at: class.updated_at
    }

  @spec allows_server_creation?(t(), DateTime.t()) :: boolean()
  def allows_server_creation?(%__MODULE__{servers_enabled: servers_enabled} = class, now),
    do: servers_enabled and active?(class, now)

  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{active: active, start_date: start_date, end_date: end_date}, now),
    do:
      active and
        (is_nil(start_date) or now |> DateTime.to_date() |> Date.compare(start_date) != :lt) and
        (is_nil(end_date) or now |> DateTime.to_date() |> Date.compare(end_date) != :gt)

  @spec refresh!(
          t(),
          ClassUpdated.t() | ClassExpectedServerPropertiesUpdated.t(),
          EventReference.t()
        ) :: t()
  def refresh!(
        %__MODULE__{} = view,
        %event_module{} = event,
        %EventReference{version: version, occurred_at: occurred_at}
      )
      when event_module in @class_events,
      do:
        versioned_refresh(
          view,
          event,
          version,
          &fetch/1,
          &merge_class(&1, &2, version, occurred_at)
        )

  defp fetch(id) do
    case Class.fetch_class(id) do
      {:ok, class} -> {:ok, from(class)}
      {:error, _reason} = error -> error
    end
  end

  defp merge_class(
         %__MODULE__{id: id} = view,
         %ClassUpdated{
           id: id,
           name: name,
           start_date: start_date,
           end_date: end_date,
           active: active,
           servers_enabled: servers_enabled,
           teacher_ssh_public_keys: teacher_ssh_public_keys,
           ssh_exercise_vm_md5_host_key_fingerprints: ssh_exercise_vm_md5_host_key_fingerprints,
           ssh_exercise_vm_sha256_host_key_fingerprints:
             ssh_exercise_vm_sha256_host_key_fingerprints
         },
         version,
         updated_at
       ),
       do: %__MODULE__{
         view
         | name: name,
           start_date: start_date,
           end_date: end_date,
           active: active,
           servers_enabled: servers_enabled,
           teacher_ssh_public_keys: teacher_ssh_public_keys,
           ssh_exercise_vm_md5_host_key_fingerprints: ssh_exercise_vm_md5_host_key_fingerprints,
           ssh_exercise_vm_sha256_host_key_fingerprints:
             ssh_exercise_vm_sha256_host_key_fingerprints,
           version: version,
           updated_at: updated_at
       }

  defp merge_class(
         %__MODULE__{id: id, expected_server_properties: expected_server_properties} = view,
         %ClassExpectedServerPropertiesUpdated{
           class: %{id: id},
           hostname: hostname,
           machine_id: machine_id,
           cpus: cpus,
           cores: cores,
           vcpus: vcpus,
           memory: memory,
           swap: swap,
           system: system,
           architecture: architecture,
           os_family: os_family,
           distribution: distribution,
           distribution_release: distribution_release,
           distribution_version: distribution_version
         },
         version,
         updated_at
       ),
       do: %__MODULE__{
         view
         | expected_server_properties:
             ExpectedServerProperties.refresh(expected_server_properties, %{
               id: expected_server_properties.id,
               hostname: hostname,
               machine_id: machine_id,
               cpus: cpus,
               cores: cores,
               vcpus: vcpus,
               memory: memory,
               swap: swap,
               system: system,
               architecture: architecture,
               os_family: os_family,
               distribution: distribution,
               distribution_release: distribution_release,
               distribution_version: distribution_version
             }),
           version: version,
           updated_at: updated_at
       }

  defp merge_class(_view, _incoming, _version, _updated_at), do: :refetch
end
