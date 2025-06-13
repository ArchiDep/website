defmodule ArchiDep.Accounts.LogInOrRegisterWithSwitchEduId do
  @moduledoc """
  User account management use case for a user to log in, creating a valid
  authentication object that can be used for authorization in other use cases.
  """
  use ArchiDep, :use_case

  import Ecto.Changeset
  alias ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId
  alias ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Accounts.Types
  alias ArchiDep.ClientMetadata
  alias ArchiDep.Students
  alias ArchiDep.Students.Schemas.Student

  @root_users :archidep |> Application.compile_env!(:root_users) |> Keyword.fetch!(:switch_edu_id)

  @spec log_in_or_register_with_switch_edu_id(
          Types.switch_edu_id_data(),
          ClientMetadata.t()
        ) ::
          {:ok, Authentication.t()}
          | {:error, :unauthorized_switch_edu_id}
  def log_in_or_register_with_switch_edu_id(
        switch_edu_id_data,
        client_metadata
      ) do
    with {:ok, %{user_session: session}} <-
           log_in_or_register(switch_edu_id_data, client_metadata) do
      {:ok, Authentication.for_user_session(session, client_metadata)}
    else
      {:error, _operation, :unauthorized_switch_edu_id, _changes} ->
        {:error, :unauthorized_switch_edu_id}
    end
  end

  defp log_in_or_register(switch_edu_id_data, client_metadata) do
    Multi.new()
    |> Multi.insert_or_update(
      :switch_edu_id,
      SwitchEduId.create_or_update(switch_edu_id_data)
    )
    |> Multi.run(
      :user_account_and_state,
      fn _repo, %{switch_edu_id: switch_edu_id} ->
        case UserAccount.fetch_for_switch_edu_id(switch_edu_id) do
          nil ->
            if Enum.member?(@root_users, switch_edu_id_data.email) ||
                 Enum.member?(@root_users, switch_edu_id_data.swiss_edu_person_unique_id) do
              {:ok,
               {:new_root, UserAccount.new_switch_edu_id_account(switch_edu_id, [:root]), nil}}
            else
              case Students.list_active_students_for_email(switch_edu_id_data.email) do
                [student] ->
                  {:ok,
                   {:new_student,
                    UserAccount.new_switch_edu_id_account(switch_edu_id, [:student]), student}}

                _zero_or_multiple_students ->
                  {:error, :unauthorized_switch_edu_id}
              end
            end

          user_account ->
            {:ok, {:existing_account, change(user_account), nil}}
        end
      end
    )
    |> Multi.insert_or_update(:user_account, fn %{
                                                  user_account_and_state:
                                                    {_state, changeset, _student}
                                                } ->
      changeset
    end)
    |> Multi.merge(fn %{
                        user_account_and_state: user_account_and_state,
                        user_account: user_account
                      } ->
      case user_account_and_state do
        {:new_student, _user_account, student} when not is_nil(student) ->
          Multi.new()
          |> Multi.update(:student, Student.link_to_user_account(student, user_account))
          |> Multi.update(:class, UserAccount.link_to_class(user_account, student.class))

        _otherwise ->
          Multi.new()
          |> Multi.run(:student, fn _repo, _changes ->
            {:ok, nil}
          end)
      end
    end)
    |> Multi.insert(:user_session, fn %{user_account: user_account} ->
      UserSession.new_session(user_account, client_metadata)
    end)
    |> insert(:stored_event, fn
      %{
        switch_edu_id: switch_edu_id,
        user_account_and_state: {state, _changeset, _student},
        user_account: user_account,
        student: student,
        user_session: session
      } ->
        case state do
          s when s in [:new_root, :new_student] ->
            UserRegisteredWithSwitchEduId.new(switch_edu_id, user_account, session, student)
            |> new_event(%{}, occurred_at: session.created_at)
            |> add_to_stream(user_account)
            |> initiated_by(user_account)

          :existing_account ->
            UserLoggedInWithSwitchEduId.new(switch_edu_id, session, client_metadata)
            |> new_event(%{}, occurred_at: session.created_at)
            |> add_to_stream(user_account)
            |> initiated_by(user_account)
        end
    end)
    |> transaction()
  end
end
