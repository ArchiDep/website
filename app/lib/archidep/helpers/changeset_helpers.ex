defmodule ArchiDep.Helpers.ChangesetHelpers do
  @moduledoc """
  Helper functions to manipulate `Ecto.Changeset`.
  """

  import Ecto.Changeset
  alias Ecto.Changeset
  alias Ecto.Query

  @doc """
  Validates that no existing record has the same value for the specified field.

  This function provides quick feedback but should not be relied on for any data
  guarantee as it has race conditions and is inherently unsafe. For example, if
  this check happens twice in the same time interval (because the user submitted
  a form twice), both checks may pass and duplicate entries may end up in the
  database. Therefore, an `Ecto.Changeset.unique_constraint/3` should also be
  used to ensure data won't get corrupted.

  However, because constraints are only checked if all validations succeed, this
  function can be used as an early check to provide early feedback to users,
  since most conflicting data will have been inserted prior to the current
  validation phase.
  """
  @spec unsafe_validate_unique_query(Changeset.t(), atom, module, (Changeset.t() -> Query.t())) ::
          Changeset.t()
  def unsafe_validate_unique_query(changeset, field, repo, query_fun)
      when is_struct(changeset, Changeset) and is_atom(field) and is_atom(repo) and
             is_function(query_fun, 1) do
    # No need to query if there is a prior error for the field
    any_prior_errors_for_fields? = Enum.any?(changeset.errors, &(elem(&1, 0) == field))

    # No need to query if we haven't changed the field in question
    unrelated_changes? = not Map.has_key?(changeset.changes, field)

    if any_prior_errors_for_fields? || unrelated_changes? do
      changeset
    else
      if changeset |> query_fun.() |> repo.exists?() do
        add_error(changeset, field, "has already been taken", validation: :unique)
      else
        changeset
      end
    end
  end
end
