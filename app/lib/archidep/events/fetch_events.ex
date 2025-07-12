defmodule ArchiDep.Events.FetchEvents do
  @moduledoc """
  Business events use case to fetch the latest events that have occurred.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Events.Policy
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Events.Types
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student

  @spec fetch_events(Authentication.t(), list(Types.fetch_events_option())) ::
          list(StoredEvent.t(struct))
  def fetch_events(auth, opts) do
    authorize!(auth, Policy, :events, :fetch_events, nil)

    events = opts |> base_query() |> before_event(opts) |> after_event(opts) |> Repo.all()
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

  defp before_event(query, opts) do
    if before = Keyword.get(opts, :older_than) do
      before_id = before.id
      before_timestamp = before.occurred_at

      from(se in query,
        where:
          se.id != ^before_id and
            (se.occurred_at < ^before_timestamp or
               (se.occurred_at == ^before_timestamp and se.id > ^before_id))
      )
    else
      query
    end
  end

  defp after_event(query, opts) do
    if aftr = Keyword.get(opts, :newer_than) do
      after_id = aftr.id
      after_timestamp = aftr.occurred_at

      from(se in query,
        where:
          se.id != ^after_id and
            (se.occurred_at > ^after_timestamp or
               (se.occurred_at == ^after_timestamp and se.id < ^after_id))
      )
    else
      query
    end
  end

  defp base_query(opts) do
    limit = opts |> Keyword.fetch!(:limit) |> validate_limit()
    from(se in StoredEvent, order_by: [desc: se.occurred_at, asc: se.id], limit: ^limit)
  end

  defp to_entity_ids_by_type(streams),
    do:
      streams
      |> Enum.map(&String.split(&1, ":"))
      |> Enum.reduce(%{}, fn
        ["classes", id], map ->
          Map.update(map, "classes", [id], fn ids -> [id | ids] end)

        ["servers", id], map ->
          Map.update(map, "servers", [id], fn ids -> [id | ids] end)

        ["students", id], map ->
          Map.update(map, "students", [id], fn ids -> [id | ids] end)

        ["user-accounts", id], map ->
          Map.update(map, "user-accounts", [id], fn ids -> [id | ids] end)
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

  defp fetch_entities_by_type({"classes", ids}) when is_list(ids),
    do: from(c in Class, where: c.id in ^ids)

  defp fetch_entities_by_type({"servers", ids}) when is_list(ids),
    do: from(s in Server, where: s.id in ^ids)

  defp fetch_entities_by_type({"students", ids}) when is_list(ids),
    do: from(s in Student, where: s.id in ^ids)

  defp fetch_entities_by_type({"user-accounts", ids}) when is_list(ids),
    do: from(ua in UserAccount, where: ua.id in ^ids)

  defp to_entities_by_stream(entities_by_type),
    do:
      Enum.reduce(entities_by_type, %{}, fn
        {"classes", classes}, map ->
          Enum.reduce(classes, map, fn class, acc ->
            Map.put(acc, "classes:#{class.id}", class)
          end)

        {"servers", servers}, map ->
          Enum.reduce(servers, map, fn class, acc ->
            Map.put(acc, "servers:#{class.id}", class)
          end)

        {"students", students}, map ->
          Enum.reduce(students, map, fn class, acc ->
            Map.put(acc, "students:#{class.id}", class)
          end)

        {"user-accounts", users}, map ->
          Enum.reduce(users, map, fn user, acc ->
            Map.put(acc, "user-accounts:#{user.id}", user)
          end)
      end)
end
