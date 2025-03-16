defmodule ArchiDep.Authorization do
  @moduledoc """
  Use this module to add authorization functions.

      defmodule MyApp.MyContext.SomeModule do
        use ArchiDep.Authorization

        def do_something(user, arg) do
          authorize!(:do_something, user, arg)
          # do the magic
        end
      end

  This module assumes the existence of a "Policy" module at the same level as
  the caller module's, e.g. "MyApp.MyContext.Policy" when used from
  "MyApp.MyContext.SomeModule". The name of the context is derived from the
  parent module, e.g. :my_context for "MyApp.MyContext.SomeModule". If any of
  these is incorrect, they can be specified as options:

      defmodule MyApp.MyContext.SomeModule do
        use ArchiDep.Authorization, policy: MyApp.SomePolicy, context: :some_context
      end
  """

  import ArchiDep.Authentication, only: [is_authentication: 1]
  alias ArchiDep.Authentication
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Helpers.NameHelpers

  @spec __using__(keyword) :: Macro.t()
  # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
  defmacro __using__(opts) when is_list(opts) do
    module = __CALLER__.module
    {policy_module, policy_context} = determine_policy_module_and_context(module, opts)

    quote bind_quoted: [policy_module: policy_module, policy_context: policy_context] do
      import ArchiDep.Authentication, only: [is_authentication: 1]
      alias ArchiDep.Authentication
      alias ArchiDep.Authorization

      @policy policy_module
      @policy_context policy_context

      @doc """
      Indicates whether the specified action is authorized.
      """
      @spec authorize(atom, Authentication.t() | nil, term) ::
              :ok | {:error, {:access_denied, atom, atom}}
      def authorize(action, auth, params \\ nil)
          when is_atom(action) and is_authentication(auth),
          do: Authorization.authorize(@policy, @policy_context, action, auth, params)

      @doc """
      Authorizes the specified action or raises a
      `ArchiDep.Errors.UnauthorizedError` error.
      """
      @spec authorize!(atom, Authentication.t() | nil, term) :: :ok
      def authorize!(action, auth, params \\ nil)
          when is_atom(action) and is_authentication(auth),
          do: Authorization.authorize!(@policy, @policy_context, action, auth, params)
    end
  end

  @doc """
  Indicates whether the specified action is authorized.
  """
  @spec authorize(module, atom, atom, Authentication.t(), term) ::
          :ok | {:error, {:access_denied, atom, atom}}
  def authorize(policy, context, action, auth, params)
      when is_atom(context) and is_atom(action) and is_authentication(auth) do
    if policy.authorize(action, auth, params) do
      :ok
    else
      {:error, {:access_denied, context, action}}
    end
  end

  @doc """
  Authorizes the specified action or raises a
  `ArchiDep.Errors.UnauthorizedError` error.
  """
  @spec authorize!(module, atom, atom, Authentication.t(), term) :: :ok
  def authorize!(policy, context, action, auth, params)
      when is_atom(context) and is_atom(action) and is_authentication(auth) do
    if policy.authorize(action, auth, params) do
      :ok
    else
      raise UnauthorizedError, context: context, action: action
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp determine_policy_module_and_context(calling_module, opts!) do
    # Get the base of the caller module, e.g. "MyApp.MyContext" when used from
    # "MyApp.MyContext.SomeModule".
    module_base =
      calling_module
      |> Atom.to_string()
      |> String.split(".")
      |> Enum.drop(-1)

    # Automatically determine the policy module by appending "Policy" to the
    # caller module's base, e.g. "MyApp.MyContext.Policy" when used from
    # "MyApp.MyContext.SomeModule".
    {policy_module, opts!} =
      Keyword.pop_lazy(opts!, :policy, fn ->
        module_base
        |> List.insert_at(-1, "Policy")
        # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
        |> Module.concat()
      end)

    # Automatically determine the context from the last part of the caller
    # module's base, e.g. :my_context when used from
    # "MyApp.MyContext.SomeModule".
    {policy_context, opts!} =
      Keyword.pop_lazy(opts!, :context, fn ->
        module_base
        |> List.last()
        |> NameHelpers.underscore()
        # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
        |> String.to_atom()
      end)

    [] = opts!

    {policy_module, policy_context}
  end
end
