defmodule ArchiDepWeb.Helpers.LiveViewHelpers do
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student

  @spec set_process_label(atom(), Authentication.t()) :: :ok
  def set_process_label(
        module,
        %Authentication{principal: %UserAccount{id: user_account_id}}
      )
      when is_atom(module),
      do:
        :proc_lib.set_label("#{Atom.to_string(module)}|ua:#{String.slice(user_account_id, 0, 5)}")

  @spec set_process_label(atom(), Authentication.t(), Class.t()) :: :ok
  def set_process_label(
        module,
        auth,
        %Class{id: class_id}
      )
      when is_atom(module),
      do: set_process_label(module, auth, "cl:#{String.slice(class_id, 0, 5)}")

  @spec set_process_label(atom(), Authentication.t(), Server.t()) :: :ok
  def set_process_label(
        module,
        auth,
        %Server{id: server_id}
      )
      when is_atom(module),
      do: set_process_label(module, auth, "sr:#{String.slice(server_id, 0, 5)}")

  @spec set_process_label(atom(), Authentication.t(), Student.t()) :: :ok
  def set_process_label(
        module,
        auth,
        %Student{id: server_id}
      )
      when is_atom(module),
      do: set_process_label(module, auth, "st:#{String.slice(server_id, 0, 5)}")

  @spec set_process_label(atom(), Authentication.t(), String.t()) :: :ok
  def set_process_label(
        module,
        %Authentication{principal: %UserAccount{id: user_account_id}},
        context
      )
      when is_atom(module) and is_binary(context),
      do:
        :proc_lib.set_label(
          "#{Atom.to_string(module)}|u:#{String.slice(user_account_id, 0, 5)}@#{context}"
        )
end
