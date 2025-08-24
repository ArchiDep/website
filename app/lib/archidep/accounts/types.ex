defmodule ArchiDep.Accounts.Types do
  @moduledoc false

  @type switch_edu_id_data :: %{
          email: String.t(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          swiss_edu_person_unique_id: String.t()
        }
end
