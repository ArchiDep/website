defmodule ArchiDep.Students.Types do
  @type class_data :: %{
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean()
        }
end
