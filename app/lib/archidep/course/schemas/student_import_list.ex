defmodule ArchiDep.Course.Schemas.StudentImportList do
  @moduledoc """
  A list of students to be imported into a course, including their academic
  class and the domain (e.g. "archidep1.ch") they will use.
  """

  use ArchiDep, :schema

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Types

  @type t :: %__MODULE__{
          academic_class: String.t() | nil,
          domain: String.t(),
          students: list(Types.import_student_data())
        }

  @alpha ?a..?z
  @alphanumeric Enum.concat([?a..?z, ?0..?9])

  @primary_key false
  embedded_schema do
    field :academic_class, :string
    field :domain, :string

    embeds_many :students, Student, primary_key: false do
      field :name, :string
      field :email, :string
    end
  end

  @spec changeset(Types.import_students_data()) :: Ecto.Changeset.t(t())
  def changeset(data) do
    %__MODULE__{}
    |> cast(data, [:academic_class, :domain])
    |> change(%{students: data.students})
    |> cast_embed(:students, required: true, with: &student_changeset/2)
    |> validate_required([:domain])
    |> validate_length(:domain, max: 20)
    |> validate_format(:domain, ~r/\A[a-z0-9][\-a-z0-9]*(?:\.[a-z][\-a-z0-9]*)+\z/i,
      message:
        "must be a valid domain name containing only letters (without accents), numbers and hyphens"
    )
  end

  @spec student_changeset(struct, map) :: Ecto.Changeset.t()
  def student_changeset(student, params) do
    student
    |> cast(params, [:name, :email])
    |> update_change(:name, &trim/1)
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/\A.+@.+\..+\z/)
  end

  @spec to_insert_data(t(), Class.t(), list(String.t()), DateTime.t()) ::
          list(Types.import_student_data())
  def to_insert_data(
        %__MODULE__{academic_class: academic_class, domain: domain, students: students},
        %Class{
          id: class_id
        },
        existing_usernames,
        now
      ) do
    students
    |> Enum.map(&Map.from_struct/1)
    |> Enum.uniq_by(& &1.email)
    |> Enum.map(
      &Map.merge(&1, %{
        id: UUID.generate(),
        academic_class: academic_class,
        username_confirmed: false,
        domain: domain,
        active: true,
        servers_enabled: false,
        class_id: class_id,
        version: 1,
        created_at: now,
        updated_at: now
      })
    )
    |> Enum.reduce({[], MapSet.new(existing_usernames)}, fn student, {list, usernames} ->
      username = generate_suggested_username(student, usernames)

      {
        [Map.put(student, :username, username) | list],
        MapSet.put(usernames, username)
      }
    end)
    |> then(&elem(&1, 0))
    |> Enum.reverse()
  end

  defp generate_suggested_username(student, taken) do
    email_name = String.replace(student.email, ~r/@.*/, "")

    if String.length(email_name) >= 4 and
         String.match?(
           email_name,
           ~r/\A[a-z][a-z0-9]+(?:-[a-z0-9]+)*(?:\.[a-z0-9]+(?:-[a-z0-9]+)*)*\Z/
         ) do
      generate_suggested_username_from_email(student.email, taken)
    else
      fn -> 3 end
      |> Stream.repeatedly()
      |> Stream.scan(fn acc, _n -> acc + 1 end)
      |> Stream.flat_map(&Enum.map(1..10, fn _n -> &1 end))
      |> Stream.map(fn size ->
        first_char = List.to_string([Enum.random(@alpha)])
        remaining_chars = random_alphanumeric(size)
        "#{first_char}#{remaining_chars}"
      end)
      |> Stream.filter(&(!MapSet.member?(taken, &1)))
      |> Enum.take(1)
      |> List.first()
    end
  end

  defp generate_suggested_username_from_email(email, taken) do
    email_name = String.replace(email, ~r/@.*/, "")
    email_name_parts = String.split(email_name, ".", parts: 2)

    case email_name_parts do
      [first_name, last_names] ->
        sanitized_first_name = String.replace(first_name, ~r/[^a-z0-9]/, "")
        sanitized_last_names = String.replace(last_names, ~r/[^a-z0-9]/, "")
        last_names_tail_chars = String.length(sanitized_last_names) - 1

        1
        |> Range.new(last_names_tail_chars)
        |> Stream.map(
          &"#{String.slice(sanitized_first_name, 0, 1)}#{String.slice(sanitized_last_names, 0, 1)}#{String.slice(sanitized_last_names, -&1, 1)}"
        )
        |> Stream.concat(
          fn -> 1 end
          |> Stream.repeatedly()
          |> Stream.scan(fn acc, _n -> acc + 1 end)
          |> Stream.map(
            &"#{String.slice(sanitized_first_name, 0, 1)}#{String.slice(sanitized_last_names, 0, 1)}#{String.slice(sanitized_last_names, -1, 1)}#{&1}"
          )
        )
        |> Stream.filter(&(!MapSet.member?(taken, &1)))
        |> Enum.take(1)
        |> List.first()

      [name] ->
        sanitized_name = String.replace(name, ~r/[^a-z0-9]/, "")
        name_tail_chars = String.length(sanitized_name) - 2

        1
        |> Range.new(name_tail_chars)
        |> Stream.map(
          &"#{String.slice(sanitized_name, 0, 2)}#{String.slice(sanitized_name, -&1, 1)}"
        )
        |> Stream.concat(
          fn -> 1 end
          |> Stream.repeatedly()
          |> Stream.scan(fn acc, _n -> acc + 1 end)
          |> Stream.map(
            &"#{String.slice(sanitized_name, 0, 2)}#{String.slice(sanitized_name, -1, 1)}#{&1}"
          )
        )
        |> Stream.filter(&(!MapSet.member?(taken, &1)))
        |> Enum.take(1)
        |> List.first()
    end
  end

  defp random_alphanumeric(size),
    do:
      1
      |> Range.new(size - 1)
      |> Enum.map(fn _n -> Enum.random(@alphanumeric) end)
      |> List.to_string()
end
