defmodule ArchiDep.Course.Types do
  @moduledoc false

  alias Ecto.UUID

  @type class_data :: %{
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          servers_enabled: boolean()
        }

  @type create_student_data :: %{
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil,
          username: String.t(),
          domain: String.t() | nil,
          active: boolean(),
          servers_enabled: boolean(),
          class_id: UUID.t()
        }

  @type existing_student_data :: %{
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil,
          username: String.t(),
          domain: String.t() | nil,
          active: boolean(),
          servers_enabled: boolean()
        }

  @type import_students_data :: %{
          academic_class: String.t() | nil,
          domain: String.t(),
          students: list(import_student_data())
        }

  @type import_student_data :: %{
          name: String.t(),
          email: String.t(),
          username: String.t()
        }

  @type student_config :: %{
          username: String.t()
        }

  @type expected_server_properties :: %{
          hostname: String.t() | nil,
          machine_id: String.t() | nil,
          cpus: pos_integer() | nil,
          cores: pos_integer() | nil,
          vcpus: pos_integer() | nil,
          memory: pos_integer() | nil,
          swap: pos_integer() | nil,
          system: String.t() | nil,
          architecture: String.t() | nil,
          os_family: String.t() | nil,
          distribution: String.t() | nil,
          distribution_release: String.t() | nil,
          distribution_version: String.t() | nil
        }
end
