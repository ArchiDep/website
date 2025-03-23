defmodule ArchiDep.Authorization do
  import ArchiDep.Authentication, only: [is_authentication: 1]
  alias ArchiDep.Authentication
  alias ArchiDep.Errors.UnauthorizedError

  @doc """
  Indicates whether the specified action is authorized.
  """
  @spec authorize(Authentication.t(), module, atom, atom, term) ::
          {:ok, Authentication.t()} | {:error, {:access_denied, atom, atom}}
  def authorize(auth, policy, context, action, params)
      when is_authentication(auth) and is_atom(context) and is_atom(action) do
    if policy.authorize(context, action, auth, params) do
      {:ok, auth}
    else
      {:error, {:access_denied, context, action}}
    end
  end

  @doc """
  Authorizes the specified action or raises a `Lair.Errors.UnauthorizedError`
  error.
  """
  @spec authorize!(Authentication.t(), module, atom, atom, term) :: Authentication.t()
  def authorize!(auth, policy, context, action, params)
      when is_authentication(auth) and is_atom(context) and is_atom(action) do
    if policy.authorize(context, action, auth, params) do
      auth
    else
      raise UnauthorizedError, context: context, action: action
    end
  end
end
