defmodule ArchiDep.Accounts.Schemas.Identity.SwitchEduIdTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.AccountsFactory
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias Ecto.Changeset

  @now ~U[2024-01-01 08:00:00.000000Z]

  describe "name/1" do
    test "is nil when both names are missing" do
      assert SwitchEduId.name(build(:switch_edu_id, first_name: nil, last_name: nil)) == nil
    end

    test "is the first name alone when the last name is missing" do
      assert SwitchEduId.name(build(:switch_edu_id, first_name: "Alice", last_name: nil)) ==
               "Alice"
    end

    test "is the last name alone when the first name is missing" do
      assert SwitchEduId.name(build(:switch_edu_id, first_name: nil, last_name: "Smith")) ==
               "Smith"
    end

    test "joins both names with a space" do
      assert SwitchEduId.name(build(:switch_edu_id, first_name: "Alice", last_name: "Smith")) ==
               "Alice Smith"
    end
  end

  describe "create_or_update/2 when no identity exists yet" do
    test "builds a new identity stamped at the given instant" do
      data =
        build(:switch_edu_id_login_data,
          first_name: "Alice",
          last_name: "Smith",
          swiss_edu_person_unique_id: "sepui-new"
        )

      changeset = SwitchEduId.create_or_update(data, @now)

      assert errors_on(changeset) == %{}
      identity = Changeset.apply_changes(changeset)
      assert {:ok, _uuid} = Ecto.UUID.cast(identity.id)

      assert identity == %SwitchEduId{
               id: identity.id,
               first_name: "Alice",
               last_name: "Smith",
               swiss_edu_person_unique_id: "sepui-new",
               version: 1,
               created_at: @now,
               updated_at: @now,
               used_at: @now
             }
    end
  end

  describe "create_or_update/2 when an identity already exists" do
    test "updates the names and bumps both timestamps when the name data changed" do
      insert(:switch_edu_id,
        swiss_edu_person_unique_id: "sepui-x",
        first_name: "Alice",
        last_name: "Smith",
        version: 2
      )

      existing = Repo.get_by!(SwitchEduId, swiss_edu_person_unique_id: "sepui-x")

      data =
        build(:switch_edu_id_login_data,
          first_name: "Alicia",
          last_name: "Smith",
          swiss_edu_person_unique_id: "sepui-x"
        )

      changeset = SwitchEduId.create_or_update(data, @now)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) == %{
               existing
               | first_name: "Alicia",
                 updated_at: @now,
                 used_at: @now
             }

      # The version bump from the optimistic lock lands only at update time, so
      # it is absent from the applied struct above.
      assert changeset.filters == %{version: 2}
    end

    test "only touches used_at, holding updated_at, when the name data is unchanged" do
      insert(:switch_edu_id,
        swiss_edu_person_unique_id: "sepui-x",
        first_name: "Alice",
        last_name: "Smith",
        version: 2
      )

      existing = Repo.get_by!(SwitchEduId, swiss_edu_person_unique_id: "sepui-x")

      data =
        build(:switch_edu_id_login_data,
          first_name: "Alice",
          last_name: "Smith",
          swiss_edu_person_unique_id: "sepui-x"
        )

      changeset = SwitchEduId.create_or_update(data, @now)

      assert errors_on(changeset) == %{}
      # Only `used_at` moves: the held `updated_at` and unchanged names are
      # pinned by asserting the whole struct equals the reloaded row.
      assert Changeset.apply_changes(changeset) == %{existing | used_at: @now}
      assert changeset.filters == %{version: 2}
    end
  end

  describe "event_stream/1" do
    test "builds the stream name from a binary id" do
      assert SwitchEduId.event_stream("sepui-42") == "accounts:switch-edu-id:sepui-42"
    end

    test "builds the stream name from an identity struct" do
      identity = build(:switch_edu_id)

      assert SwitchEduId.event_stream(identity) == "accounts:switch-edu-id:#{identity.id}"
    end
  end
end
