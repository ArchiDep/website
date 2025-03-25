defmodule ArchiDep.Students.Policy do
  use ArchiDep, :policy

  @impl Policy

  # Root users can create classes.
  def authorize(
        :students,
        :create_class,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can list classes.
  def authorize(
        :students,
        :list_classes,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  def authorize(_action, _principal, _params), do: false
end
