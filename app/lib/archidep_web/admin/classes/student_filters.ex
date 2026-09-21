defmodule ArchiDepWeb.Admin.Classes.StudentFilters do
  @moduledoc """
  The filters narrowing the student list of the admin class page. They are read
  from and written to the page's query parameters, so that a filtered list
  survives a reload and can be bookmarked or navigated back to.
  """

  alias ArchiDep.Course.StudentView

  # Casting turns a blank academic class into `nil`, so no student can have this
  # one.
  @no_academic_class " "

  @enforce_keys [:academic_class, :registered]
  defstruct [:academic_class, :registered]

  @type academic_class :: String.t() | :none

  @type t :: %__MODULE__{
          academic_class: academic_class() | nil,
          registered: boolean() | nil
        }

  @doc """
  Returns the filters that let every student through.
  """
  @spec none() :: t()
  def none, do: %__MODULE__{academic_class: nil, registered: nil}

  @doc """
  Parses filters from query parameters, ignoring missing or unknown values.
  """
  @spec from_params(map()) :: t()
  def from_params(params) when is_map(params),
    do: %__MODULE__{
      academic_class: parse_academic_class(Map.get(params, "academic_class")),
      registered: parse_registered(Map.get(params, "registered"))
    }

  @doc """
  Serializes filters to query parameters, omitting the inactive ones.
  """
  @spec to_params(t()) :: %{String.t() => String.t()}
  def to_params(%__MODULE__{academic_class: academic_class, registered: registered}),
    do:
      [
        {"academic_class", academic_class && academic_class_param(academic_class)},
        {"registered", registered_param(registered)}
      ]
      |> Enum.reject(fn {_key, value} -> value == nil end)
      |> Map.new()

  @doc """
  Returns the query parameter value selecting the given academic class filter.
  """
  @spec academic_class_param(academic_class()) :: String.t()
  def academic_class_param(:none), do: @no_academic_class
  def academic_class_param(academic_class) when is_binary(academic_class), do: academic_class

  @doc """
  Returns the query parameter value selecting the given registration filter.
  """
  @spec registered_param(boolean() | nil) :: String.t() | nil
  def registered_param(true), do: "yes"
  def registered_param(false), do: "no"
  def registered_param(nil), do: nil

  @doc """
  Indicates whether at least one filter is active.
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{} = filters), do: filters != none()

  @doc """
  Returns the students matching every active filter, in their original order.
  """
  @spec filter(t(), list(StudentView.t())) :: list(StudentView.t())
  def filter(%__MODULE__{} = filters, students),
    do:
      Enum.filter(
        students,
        &(match_academic_class?(filters.academic_class, &1) and
            match_registered?(filters.registered, &1))
      )

  @doc """
  Returns the academic classes the students can be filtered by: each distinct
  academic class in alphabetical order, followed by `:none` if a student has
  none. The currently filtered academic class is always included, so that the
  filter can still be seen and changed when no student matches it.
  """
  @spec academic_class_options(t(), list(StudentView.t())) :: list(academic_class())
  def academic_class_options(%__MODULE__{academic_class: current}, students) do
    present = Enum.map(students, &(&1.academic_class || :none))

    {none, named} =
      [current | present]
      |> Enum.reject(&(&1 == nil))
      |> Enum.uniq()
      |> Enum.split_with(&(&1 == :none))

    Enum.sort(named) ++ none
  end

  defp parse_academic_class(@no_academic_class), do: :none

  defp parse_academic_class(academic_class) when is_binary(academic_class),
    do: if(academic_class == "", do: nil, else: academic_class)

  defp parse_academic_class(_value), do: nil

  defp parse_registered("yes"), do: true
  defp parse_registered("no"), do: false
  defp parse_registered(_value), do: nil

  defp match_academic_class?(nil, _student), do: true
  defp match_academic_class?(:none, student), do: student.academic_class == nil

  defp match_academic_class?(academic_class, student),
    do: student.academic_class == academic_class

  defp match_registered?(nil, _student), do: true
  defp match_registered?(registered, student), do: student.user_id != nil == registered
end
