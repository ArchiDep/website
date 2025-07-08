defmodule ArchiDep.Accounts.Schemas.UserGroup do
  @moduledoc """
  A user group represents a number of users that can be activated/deactivated
  together and that may only be active for a given period of time.
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
end
