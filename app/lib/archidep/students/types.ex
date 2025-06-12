defmodule ArchiDep.Students.Types do
  alias Ecto.UUID

  @type class_data :: %{
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          expected_server_cpus: pos_integer() | nil,
          expected_server_cores: pos_integer() | nil,
          expected_server_vcpus: pos_integer() | nil,
          expected_server_memory: pos_integer() | nil,
          expected_server_swap: pos_integer() | nil,
          expected_server_system: String.t() | nil,
          expected_server_architecture: String.t() | nil,
          expected_server_os_family: String.t() | nil,
          expected_server_distribution: String.t() | nil,
          expected_server_distribution_release: String.t() | nil,
          expected_server_distribution_version: String.t() | nil
        }

  @type create_student_data :: %{
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil,
          class_id: UUID.t()
        }

  @type existing_student_data :: %{
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil
        }

  @type import_students_data :: %{
          academic_class: String.t() | nil,
          students:
            list(%{
              name: String.t(),
              email: String.t(),
              academic_class: String.t() | nil
            })
        }
end
