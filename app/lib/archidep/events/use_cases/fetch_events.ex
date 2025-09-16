defmodule ArchiDep.Events.UseCases.FetchEvents do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Events.Policy
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Events.Types
  alias ArchiDep.Servers.Schemas.Server

  @spec fetch_events(Authentication.t(), list(Types.fetch_events_option())) ::
          list(StoredEvent.t(struct))
  def fetch_events(auth, opts) do
    authorize!(auth, Policy, :events, :fetch_events, nil)

    events =
      opts
      |> base_query()
      |> before_event(Keyword.get(opts, :older_than))
      |> after_event(Keyword.get(opts, :newer_than))
      |> Repo.all()

    streams = events |> Enum.map(& &1.stream) |> Enum.uniq()

    entities =
      streams
      |> to_entity_ids_by_type()
      |> fetch_entities_by_type()
      |> to_entities_by_stream()

    Enum.map(events, fn stored_event ->
      %StoredEvent{stored_event | entity: Map.get(entities, stored_event.stream)}
    end)
  end

  @spec fetch_event(Authentication.t(), UUID.t()) ::
          {:ok, StoredEvent.t(struct)} | {:error, :event_not_found}
  def fetch_event(auth, id) do
    with :ok <- validate_uuid(id, :event_not_found),
         {:ok, event} <- StoredEvent.fetch_event(id),
         :ok <- authorize(auth, Policy, :events, :fetch_event, event) do
      {:ok, event}
    else
      {:error, {:access_denied, :events, :fetch_event}} -> {:error, :event_not_found}
      {:error, :event_not_found} -> {:error, :event_not_found}
    end
  end

  defp before_event(query, nil), do: query

  defp before_event(query, {before_id, before_timestamp}),
    do:
      from(se in query,
        where:
          se.id != ^before_id and
            (se.occurred_at < ^before_timestamp or
               (se.occurred_at == ^before_timestamp and se.id > ^before_id))
      )

  defp after_event(query, nil), do: query

  defp after_event(query, {after_id, after_timestamp}),
    do:
      from(se in query,
        where:
          se.id != ^after_id and
            (se.occurred_at > ^after_timestamp or
               (se.occurred_at == ^after_timestamp and se.id < ^after_id))
      )

  defp base_query(opts) do
    limit = opts |> Keyword.fetch!(:limit) |> validate_limit()
    from(se in StoredEvent, order_by: [desc: se.occurred_at, asc: se.id], limit: ^limit)
  end

  defp to_entity_ids_by_type(streams),
    do:
      streams
      |> Enum.map(&String.split(&1, ":"))
      |> Enum.reduce(%{}, fn
        ["accounts", "preregistered-users", id], map ->
          Map.update(map, "accounts:preregistered-users", [id], fn ids -> [id | ids] end)

        ["accounts", "user-accounts", id], map ->
          Map.update(map, "accounts:user-accounts", [id], fn ids -> [id | ids] end)

        ["course", "classes", id], map ->
          Map.update(map, "course:classes", [id], fn ids -> [id | ids] end)

        ["course", "students", id], map ->
          Map.update(map, "course:students", [id], fn ids -> [id | ids] end)

        ["servers", "servers", id], map ->
          Map.update(map, "servers:servers", [id], fn ids -> [id | ids] end)
      end)

  defp fetch_entities_by_type(entity_ids_by_type) when is_map(entity_ids_by_type),
    do:
      entity_ids_by_type
      |> Map.new(fn
        {type, ids} -> {type, fetch_entities_by_type({type, ids})}
      end)
      |> Map.new(fn
        {type, query} -> {type, Task.async(fn -> Repo.all(query) end)}
      end)
      |> Map.new(fn
        {type, task} -> {type, Task.await(task)}
      end)

  defp fetch_entities_by_type({"accounts:preregistered-users", ids}) when is_list(ids),
    do:
      from(pu in PreregisteredUser,
        where: pu.id in ^ids,
        join: ug in assoc(pu, :group),
        left_join: ua in assoc(pu, :user_account),
        preload: [group: ug, user_account: ua]
      )

  defp fetch_entities_by_type({"accounts:user-accounts", ids}) when is_list(ids),
    do:
      from(ua in UserAccount,
        where: ua.id in ^ids,
        left_join: sei in assoc(ua, :switch_edu_id),
        left_join: pu in assoc(ua, :preregistered_user),
        preload: [switch_edu_id: sei, preregistered_user: pu]
      )

  defp fetch_entities_by_type({"course:classes", ids}) when is_list(ids),
    do: from(c in Class, where: c.id in ^ids)

  defp fetch_entities_by_type({"course:students", ids}) when is_list(ids),
    do: from(s in Student, where: s.id in ^ids)

  defp fetch_entities_by_type({"servers:servers", ids}) when is_list(ids),
    do: from(s in Server, where: s.id in ^ids)

  defp to_entities_by_stream(entities_by_type),
    do:
      Enum.reduce(entities_by_type, %{}, fn
        {"accounts:preregistered-users", users}, map ->
          Enum.reduce(users, map, fn user, acc ->
            Map.put(acc, "accounts:preregistered-users:#{user.id}", user)
          end)

        {"accounts:user-accounts", users}, map ->
          Enum.reduce(users, map, fn user, acc ->
            Map.put(acc, "accounts:user-accounts:#{user.id}", user)
          end)

        {"course:classes", classes}, map ->
          Enum.reduce(classes, map, fn class, acc ->
            Map.put(acc, "course:classes:#{class.id}", class)
          end)

        {"course:students", students}, map ->
          Enum.reduce(students, map, fn class, acc ->
            Map.put(acc, "course:students:#{class.id}", class)
          end)

        {"servers:servers", servers}, map ->
          Enum.reduce(servers, map, fn class, acc ->
            Map.put(acc, "servers:servers:#{class.id}", class)
          end)
      end)
end
