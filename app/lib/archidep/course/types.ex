defmodule ArchiDep.Course.Types do
  @moduledoc false

  @type class_data :: %{
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          servers_enabled: boolean(),
          teacher_ssh_public_keys: list(String.t()),
          ssh_exercise_vm_md5_host_key_fingerprints: String.t() | nil,
          ssh_exercise_vm_sha256_host_key_fingerprints: String.t() | nil
        }

  @type student_data :: %{
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
          email: String.t()
        }

  @type student_config :: %{
          username: String.t()
        }

  @type expected_server_properties :: %{
          optional(:hostname) => String.t() | nil,
          optional(:machine_id) => String.t() | nil,
          optional(:cpus) => pos_integer() | nil,
          optional(:cores) => pos_integer() | nil,
          optional(:vcpus) => pos_integer() | nil,
          optional(:memory) => pos_integer() | nil,
          optional(:swap) => pos_integer() | nil,
          optional(:system) => String.t() | nil,
          optional(:architecture) => String.t() | nil,
          optional(:os_family) => String.t() | nil,
          optional(:distribution) => String.t() | nil,
          optional(:distribution_release) => String.t() | nil,
          optional(:distribution_version) => String.t() | nil
        }
end
