defmodule ArchiDep.CourseSite.Builder.Report do
  @moduledoc """
  What a build turned out to be, in numbers.

  A build either produces a directory or says what is wrong with the course, so
  there is nothing to report about *how* it went. What is left is what it was
  made of, which is what a caller with a console prints and what a caller
  without one has to compare two builds by.
  """

  @enforce_keys [:output_dir, :pages, :chapters, :files, :page_assets, :assets]
  defstruct [:output_dir, :pages, :chapters, :files, :page_assets, :assets]

  @type t :: %__MODULE__{
          output_dir: Path.t(),
          pages: non_neg_integer(),
          chapters: non_neg_integer(),
          files: non_neg_integer(),
          page_assets: non_neg_integer(),
          assets: non_neg_integer()
        }
end
