defmodule ArchiDepWeb.Admin.Classes.Export.Format do
  @moduledoc """
  A format the students of a class can be exported in, from the export dialog of
  the admin class page or as a download. See `ArchiDepWeb.Admin.Classes.Export`.
  """

  alias ArchiDep.Course.ClassView
  alias ArchiDepWeb.Admin.Classes.Export

  @doc """
  Returns the identifier of the format, used in the download URL.
  """
  @callback id() :: String.t()

  @doc """
  Returns the name of the format shown in the export dialog.
  """
  @callback label() :: String.t()

  @doc """
  Returns the name of the file the format is downloaded as.
  """
  @callback filename(ClassView.t()) :: String.t()

  @doc """
  Returns the content type the format is downloaded with.
  """
  @callback content_type() :: String.t()

  @doc """
  Indicates whether the format needs the active servers of the students, so
  that they are only loaded for the formats that use them.
  """
  @callback needs_servers?() :: boolean()

  @doc """
  Indicates whether a student, with their active server if they have one, can
  be part of the export. The students who cannot are listed in the export dialog
  instead.
  """
  @callback included?(Export.entry()) :: boolean()

  @doc """
  Renders the export, which only holds the students the format includes. With
  `redact` set, the secrets it contains are replaced by `***`, so that the text
  can be shown on screen.
  """
  @callback render(Export.t(), redact :: boolean()) :: String.t()
end
