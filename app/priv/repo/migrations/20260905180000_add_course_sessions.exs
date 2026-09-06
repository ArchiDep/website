defmodule ArchiDep.Repo.Migrations.AddCourseSessions do
  use Ecto.Migration

  @categories [:done, :due, :next]

  def change do
    create table(:course_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :date, :date, null: false
      add :title, :text, null: false
      add :done, {:array, :integer}, null: false, default: []
      add :due, {:array, :integer}, null: false, default: []
      add :next, {:array, :integer}, null: false, default: []
      add :version, :bigint, null: false
      timestamps(inserted_at: :created_at, required: true, type: :utc_datetime_usec)
    end

    # The order the sessions were taught, which is the order they are read in.
    create index(:course_sessions, [:date, :created_at], name: :course_sessions_order_index)

    create constraint(:course_sessions, :created_at_and_updated_at_are_consistent,
             check: """
             updated_at >= created_at
             """
           )

    create constraint(:course_sessions, :version_is_positive, check: "version >= 1")

    create constraint(:course_sessions, :title_is_not_blank,
             check: """
             btrim(title) <> ''
             """
           )

    # A section or chapter number, which the course numbers from 100 up. Both
    # halves are needed: a check constraint passes on NULL, so `0 < ALL(...)`
    # alone would accept an array holding one.
    for category <- @categories do
      create constraint(:course_sessions, :"#{category}_holds_section_or_chapter_numbers",
               check: """
               0 < ALL(#{category}) AND array_position(#{category}, NULL) IS NULL
               """
             )
    end
  end
end
