defmodule ArchiDep.Accounts.CreateLoginLinksTest do
  use ArchiDep.Support.DataCase, async: true

  import Ecto.Query, only: [from: 2]
  import Hammox
  import ArchiDep.Support.TokenTestHelpers
  alias ArchiDep.Accounts.Behaviour
  alias ArchiDep.Accounts.Context
  alias ArchiDep.Accounts.Schemas.LoginLink
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Clock
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory
  alias Ecto.UUID

  # Pinned instant returned by the injected clock for the duration of each test,
  # so that every timestamp produced by the use case can be asserted exactly
  # (see docs/testing.md).
  @now ~U[2024-03-15 10:30:00.000000Z]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      create_login_link:
        protect({Context, :create_login_link_for_preregistered_user, 2}, Behaviour)
    }
  end

  test "create a login link for a preregistered user", %{create_login_link: create_login_link} do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    auth = Factory.build(:authentication, root: true)

    # The use case echoes back the link with its `preregistered_user` association
    # loaded exactly as the use case fetched it (group preloaded, no user
    # account); `user_account` is left unloaded. Bind the same fetch to pin it.
    {:ok, preregistered_user} = PreregisteredUser.fetch_preregistered_user(student.id)

    assert {:ok, login_link} = create_login_link.(auth, student.id)

    login_link
    |> assert_created_login_link(preregistered_user)
    |> assert_link_created_event(auth, student)
    |> assert_persisted_login_link(login_link.token)

    assert [_only_one] = persisted_login_links()
  end

  test "deactivate any previous login links for the preregistered user", %{
    create_login_link: create_login_link
  } do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    previous_links =
      for _n <- 1..2 do
        AccountsFactory.insert(:login_link,
          preregistered_user_id: student.id,
          active: true,
          now: @now
        )
      end

    auth = Factory.build(:authentication, root: true)

    {:ok, preregistered_user} = PreregisteredUser.fetch_preregistered_user(student.id)

    assert {:ok, login_link} = create_login_link.(auth, student.id)

    login_link
    |> assert_created_login_link(preregistered_user)
    |> assert_link_created_event(auth, student)
    |> assert_persisted_login_link(login_link.token)

    # Each previous link is deactivated in place: only the `active` flag flips,
    # it is not marked as used.
    for previous_link <- previous_links do
      assert_login_link_deactivated(previous_link)
    end

    # Exactly the two previous links plus the freshly created one, with only the
    # new link left active.
    links = persisted_login_links()
    assert length(links) == 3
    assert [active_link] = Enum.filter(links, & &1.active)
    assert active_link.id == login_link.id
  end

  test "a non-root user cannot create a login link", %{create_login_link: create_login_link} do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    auth = Factory.build(:authentication, root: false)

    assert {:error, :unauthorized} = create_login_link.(auth, student.id)

    assert [] = persisted_login_links()
    assert_no_stored_events!()
  end

  test "a login link cannot be created for an unknown preregistered user", %{
    create_login_link: create_login_link
  } do
    auth = Factory.build(:authentication, root: true)

    assert {:error, :preregistered_user_not_found} = create_login_link.(auth, UUID.generate())

    assert [] = persisted_login_links()
    assert_no_stored_events!()
  end

  test "a login link cannot be created for an invalid preregistered user ID", %{
    create_login_link: create_login_link
  } do
    auth = Factory.build(:authentication, root: true)

    # A 36-byte string satisfies the behaviour's `UUID.t()` contract (so the
    # protected call is not rejected before it runs) but is not a valid UUID, so
    # the use case's own `validate_uuid` guard rejects it.
    assert {:error, :preregistered_user_not_found} =
             create_login_link.(auth, String.duplicate("x", 36))

    assert [] = persisted_login_links()
    assert_no_stored_events!()
  end

  test "a login link is never created for a root account", %{
    create_login_link: create_login_link
  } do
    # Security invariant (generation side): the use case only ever targets a
    # preregistered user, so the link it produces is bound to that user and
    # never to a user account — root or otherwise. Even in the one case where a
    # root account is reachable through the data graph (a student whose
    # `user_account_id` points at a standalone root account), the created link
    # carries `user_account_id: nil` (pinned by the assertions below), so it can
    # never authenticate the root account. The consumption side
    # (`LogInOrRegisterWithLink`) additionally rejects such a link.
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    root_account =
      AccountsFactory.insert(:user_account,
        root: true,
        active: true,
        switch_edu_id: nil,
        now: @now
      )

    link_student_to_user_account(student, root_account)

    auth = Factory.build(:authentication, root: true)

    {:ok, preregistered_user} = PreregisteredUser.fetch_preregistered_user(student.id)

    assert {:ok, login_link} = create_login_link.(auth, student.id)

    login_link
    |> assert_created_login_link(preregistered_user)
    |> assert_link_created_event(auth, student)
    |> assert_persisted_login_link(login_link.token)

    assert [_only_one] = persisted_login_links()
    assert_user_account_untouched(root_account)
  end

  # Asserts the use case's return value exactly: a single, active, unused link
  # bound to the preregistered user (with its association echoed back as the use
  # case loaded it) and to no user account, stamped at the pinned instant. The
  # token cannot be pinned to an exact value, so it is bound for cross-reference
  # and separately checked to look like a securely generated secret.
  defp assert_created_login_link(
         %LoginLink{} = login_link,
         %PreregisteredUser{} = preregistered_user
       ) do
    assert %LoginLink{id: id, token: token} = login_link
    assert_secure_random_token(token)

    assert login_link == %LoginLink{
             __meta__: loaded(LoginLink, "login_links"),
             id: id,
             token: token,
             active: true,
             used_at: nil,
             preregistered_user: preregistered_user,
             preregistered_user_id: preregistered_user.id,
             user_account: not_loaded(:user_account, LoginLink),
             user_account_id: nil,
             created_at: @now
           }

    login_link
  end

  defp assert_link_created_event(%LoginLink{id: link_id}, auth, student) do
    assert [%StoredEvent{id: event_id} = created_event] = fetch_new_stored_events()

    assert created_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "accounts:preregistered-users:#{student.id}",
             version: student.version,
             type: "archidep/accounts/preregistered-user-login-link-created",
             data: %{
               "id" => link_id,
               "preregistered_user" => %{
                 "id" => student.id,
                 "name" => student.name,
                 "email" => student.email
               }
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    created_event
  end

  # Reconstructs the expected persisted row entirely from the already-asserted
  # audit event (link id, preregistered user, timestamp) plus the token — the
  # one value the event deliberately omits because it is a secret. Receiving the
  # event rather than the returned link both proves the event is a sufficient
  # audit log and avoids checking the row against the use case's own output.
  defp assert_persisted_login_link(
         %StoredEvent{
           data: %{
             "id" => link_id,
             "preregistered_user" => %{"id" => preregistered_user_id}
           },
           occurred_at: created_at
         },
         token
       ) do
    assert Repo.get!(LoginLink, link_id) == %LoginLink{
             __meta__: loaded(LoginLink, "login_links"),
             id: link_id,
             token: token,
             active: true,
             used_at: nil,
             preregistered_user: not_loaded(:preregistered_user, LoginLink),
             preregistered_user_id: preregistered_user_id,
             user_account: not_loaded(:user_account, LoginLink),
             user_account_id: nil,
             created_at: created_at
           }
  end

  defp assert_login_link_deactivated(%LoginLink{} = previous_link) do
    assert Repo.get!(LoginLink, previous_link.id) == %{
             previous_link
             | active: false,
               preregistered_user: not_loaded(:preregistered_user, LoginLink),
               user_account: not_loaded(:user_account, LoginLink)
           }
  end

  defp assert_user_account_untouched(user_account) do
    assert Repo.all(UserAccount) == [
             %{
               user_account
               | switch_edu_id: not_loaded(:switch_edu_id, UserAccount),
                 preregistered_user: not_loaded(:preregistered_user, UserAccount)
             }
           ]
  end

  defp link_student_to_user_account(%{id: student_id}, %UserAccount{id: user_account_id}) do
    {1, nil} =
      Repo.update_all(from(s in Student, where: s.id == ^student_id),
        set: [user_id: user_account_id]
      )

    :ok
  end

  defp persisted_login_links do
    Repo.all(LoginLink)
  end
end
