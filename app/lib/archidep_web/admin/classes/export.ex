defmodule ArchiDepWeb.Admin.Classes.Export do
  @moduledoc """
  The students of a class, each with their active server if they have one, as
  the formats of the export dialog of the admin class page and of its downloads
  receive them. Each format is a module implementing
  `ArchiDepWeb.Admin.Classes.Export.Format`, and decides which students it can
  include.
  """

  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.StudentView
  alias ArchiDep.Servers.ServerView
  alias ArchiDepWeb.Admin.Classes.Export.Csv
  alias ArchiDepWeb.Admin.Classes.Export.DnsRecords
  alias ArchiDepWeb.Admin.Classes.Export.Emails
  alias ArchiDepWeb.Admin.Classes.Export.KnownHosts
  alias ArchiDepWeb.Admin.Classes.Export.SshConfig
  alias ArchiDepWeb.Admin.Classes.Export.SshExerciseInventory

  @enforce_keys [:class, :entries, :generated_at]
  defstruct [:class, :entries, :generated_at]

  @type entry :: {StudentView.t(), ServerView.t() | nil}

  @type t :: %__MODULE__{
          class: ClassView.t(),
          entries: list(entry()),
          generated_at: DateTime.t()
        }

  @formats [Emails, Csv, SshExerciseInventory, KnownHosts, SshConfig, DnsRecords]

  @doc """
  Returns the export formats, in the order the export dialog shows them.
  """
  @spec formats() :: list(module())
  def formats, do: @formats

  @doc """
  Finds the export format with the given identifier.
  """
  @spec fetch_format(String.t()) :: {:ok, module()} | {:error, :format_not_found}
  def fetch_format(id) when is_binary(id) do
    case Enum.find(@formats, &(&1.id() == id)) do
      nil -> {:error, :format_not_found}
      format -> {:ok, format}
    end
  end

  @doc """
  Pairs each student with their active server, found among the given servers by
  the student's identifier, keeping the order of the students.
  """
  @spec new(ClassView.t(), list(StudentView.t()), list(ServerView.t()), DateTime.t()) :: t()
  def new(class, students, servers, generated_at) do
    servers_by_student = Map.new(servers, &{&1.owner.group_member_id, &1})

    %__MODULE__{
      class: class,
      entries: Enum.map(students, &{&1, Map.get(servers_by_student, &1.id)}),
      generated_at: generated_at
    }
  end

  @doc """
  Returns the students the given format cannot include.
  """
  @spec excluded_students(t(), module()) :: list(StudentView.t())
  def excluded_students(%__MODULE__{entries: entries}, format),
    do: for({student, _server} = entry <- entries, not format.included?(entry), do: student)

  @doc """
  Renders the export in the given format, with the students it can include.
  """
  @spec render(t(), module(), boolean()) :: String.t()
  def render(%__MODULE__{entries: entries} = export, format, redact),
    do:
      format.render(
        %__MODULE__{export | entries: Enum.filter(entries, &format.included?/1)},
        redact
      )

  @doc """
  Returns the hostname of a student's server, the subdomain the course assigns
  to them.
  """
  @spec hostname(StudentView.t()) :: String.t()
  def hostname(%StudentView{username: username, domain: domain}), do: "#{username}.#{domain}"

  @doc """
  Returns the IP address of a server as text.
  """
  @spec ip_address(ServerView.t()) :: String.t()
  def ip_address(%ServerView{ip_address: %Postgrex.INET{address: address}}),
    do: address |> :inet.ntoa() |> to_string()
end
