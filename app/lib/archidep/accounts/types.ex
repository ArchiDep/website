defmodule ArchiDep.Accounts.Types do
  @type switch_edu_id_data :: %{
          email: String.t(),
          first_name: String.t(),
          last_name: String.t() | nil,
          swiss_edu_person_unique_id: String.t()
        }
end
