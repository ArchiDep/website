defmodule ArchiDep.Accounts.Schemas.UserGroupTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.AccountsFactory
  alias ArchiDep.Accounts.Schemas.UserGroup

  # `active?/2` compares the date part of `now` against the group's date window,
  # so a fixed instant pins which day "now" falls on. Its date is 2024-01-01.
  @now ~U[2024-01-01 08:00:00.000000Z]

  describe "active?/2" do
    test "an inactive group is never active, even within its window" do
      group =
        build(:user_group, active: false, start_date: ~D[2023-12-01], end_date: ~D[2024-02-01])

      refute UserGroup.active?(group, @now)
    end

    test "an active group with no date bounds is always active" do
      group = build(:user_group, active: true, start_date: nil, end_date: nil)

      assert UserGroup.active?(group, @now)
    end

    test "a group whose start date is in the future is not yet active" do
      group = build(:user_group, active: true, start_date: ~D[2024-01-02], end_date: nil)

      refute UserGroup.active?(group, @now)
    end

    test "a group is active on its start date (inclusive)" do
      group = build(:user_group, active: true, start_date: ~D[2024-01-01], end_date: nil)

      assert UserGroup.active?(group, @now)
    end

    test "a group is active strictly within its window" do
      group =
        build(:user_group, active: true, start_date: ~D[2023-12-01], end_date: ~D[2024-02-01])

      assert UserGroup.active?(group, @now)
    end

    test "a group is active on its end date (inclusive)" do
      group = build(:user_group, active: true, start_date: nil, end_date: ~D[2024-01-01])

      assert UserGroup.active?(group, @now)
    end

    test "a group whose end date has passed is no longer active" do
      group = build(:user_group, active: true, start_date: nil, end_date: ~D[2023-12-31])

      refute UserGroup.active?(group, @now)
    end

    test "a group with only a start date is active once it has started" do
      started = build(:user_group, active: true, start_date: ~D[2023-12-01], end_date: nil)
      not_started = build(:user_group, active: true, start_date: ~D[2024-01-02], end_date: nil)

      assert UserGroup.active?(started, @now)
      refute UserGroup.active?(not_started, @now)
    end

    test "a group with only an end date is active until it ends" do
      open = build(:user_group, active: true, start_date: nil, end_date: ~D[2024-02-01])
      ended = build(:user_group, active: true, start_date: nil, end_date: ~D[2023-12-31])

      assert UserGroup.active?(open, @now)
      refute UserGroup.active?(ended, @now)
    end
  end
end
