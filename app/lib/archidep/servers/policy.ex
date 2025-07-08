defmodule ArchiDep.Servers.Policy do
  use ArchiDep, :policy

  alias ArchiDep.Servers.Schemas.Server

  @impl Policy

  # Students can validate servers for themselves (in their own class).
  def authorize(
        :servers,
        :validate_server,
        %Authentication{
          principal: %UserAccount{
            active: true,
            roles: roles,
            preregistered_user: preregistered_user
          }
        },
        %{class_id: nil}
      )
      when not is_nil(preregistered_user),
      do: Enum.member?(roles, :student)

  # Root users can validate any server.
  def authorize(
        :servers,
        :validate_server,
        %Authentication{principal: %UserAccount{active: true, roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Students can create servers for themselves (in their own class).
  def authorize(
        :servers,
        :create_server,
        %Authentication{
          principal: %UserAccount{
            active: true,
            roles: roles,
            preregistered_user: preregistered_user
          }
        },
        %{class_id: nil}
      )
      when not is_nil(preregistered_user),
      do: Enum.member?(roles, :student)

  # Root users can create any server.
  def authorize(
        :servers,
        :create_server,
        %Authentication{principal: %UserAccount{active: true, roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Students and root users can list their servers.
  def authorize(
        :servers,
        :list_my_servers,
        %Authentication{principal: %UserAccount{active: true, roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Students and root users can fetch a server that belongs to them.
  def authorize(
        :servers,
        :fetch_server,
        %Authentication{principal: %UserAccount{id: principal_id, active: true, roles: roles}},
        %Server{user_account_id: principal_id}
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Root users can fetch servers belonging to other users.
  def authorize(
        :servers,
        :fetch_server,
        %Authentication{principal: %UserAccount{active: true, roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Students can retry connecting to their own servers.
  def authorize(
        :servers,
        :retry_connecting,
        %Authentication{principal: %UserAccount{id: principal_id, active: true, roles: roles}},
        %Server{user_account_id: principal_id}
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Root users can retry connecting to any server.
  def authorize(
        :servers,
        :retry_connecting,
        %Authentication{principal: %UserAccount{active: true, roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can retry running ansible playbooks.
  def authorize(
        :servers,
        :retry_ansible_playbook,
        %Authentication{principal: %UserAccount{active: true, roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Students and root users can validate their own existing servers.
  def authorize(
        :servers,
        :validate_existing_server,
        %Authentication{principal: %UserAccount{id: principal_id, active: true, roles: roles}},
        %Server{user_account_id: principal_id}
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Root users can validate any existing server.
  def authorize(
        :servers,
        :validate_existing_server,
        %Authentication{principal: %UserAccount{active: true, roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Student and root users can update their own servers.
  def authorize(
        :servers,
        :update_server,
        %Authentication{principal: %UserAccount{id: principal_id, active: true, roles: roles}},
        %Server{user_account_id: principal_id}
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Root users can update any server.
  def authorize(
        :servers,
        :update_server,
        %Authentication{principal: %UserAccount{active: true, roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can delete servers.
  def authorize(
        :servers,
        :delete_server,
        %Authentication{principal: %UserAccount{active: true, roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  def authorize(_context, _action, _principal, _params), do: false
end
