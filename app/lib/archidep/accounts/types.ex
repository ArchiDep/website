defmodule ArchiDep.Accounts.Types do
  # TODO: remove and replace by ArchiDep.Types
  @type role :: :root | :student

  @type switch_edu_id_data :: %{
          email: String.t(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          swiss_edu_person_unique_id: String.t()
        }
end
