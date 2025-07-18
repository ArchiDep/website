defmodule ArchiDep.Accounts.Schemas.UserGroup do
  @moduledoc """
  A user group represents a number of user accounts that can be
  activated/deactivated together and that may only be active for a given period
  of time.
  """

  use ArchiDep, :schema

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean()
        }

  schema "classes" do
    field(:name, :binary)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:active, :boolean)
  end

  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{active: active, start_date: start_date, end_date: end_date}, now),
    do:
      active and
        (is_nil(start_date) or now |> DateTime.to_date() |> Date.compare(start_date) != :lt) and
        (is_nil(end_date) or now |> DateTime.to_date() |> Date.compare(end_date) != :gt)

  @spec where_user_group_active(DateTime.t()) :: Queryable.t()
  def where_user_group_active(now),
    do:
      dynamic(
        [user_group: ug],
        ug.active and
          (is_nil(ug.start_date) or ug.start_date <= ^now) and
          (is_nil(ug.end_date) or ug.end_date >= ^now)
      )
end
