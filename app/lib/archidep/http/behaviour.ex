defmodule ArchiDep.Http.Behaviour do
  @moduledoc """
  Behavior of the HTTP client module.
  """

  alias Req.Request
  alias Req.Response

  @callback get(url :: URI.t() | String.t() | Request.t(), Keyword.t()) ::
              {:ok, Response.t()} | {:error, Exception.t()}
end
