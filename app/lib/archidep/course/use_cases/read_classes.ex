defmodule ArchiDep.Course.UseCases.ReadClasses do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Clock
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class

  @spec fetch_class(Authentication.t() | nil, UUID.t()) ::
          {:ok, Class.t()} | {:error, :class_not_found}
  def fetch_class(auth, id) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id),
         :ok <- authorize(auth, Policy, :course, :fetch_class, class) do
      {:ok, class}
    else
      {:error, :class_not_found} ->
        {:error, :class_not_found}

      {:error, {:access_denied, :course, :fetch_class}} ->
        {:error, :class_not_found}
    end
  end

  @spec list_classes(Authentication.t()) :: list(Class.t())
  def list_classes(auth) do
    authorize!(auth, Policy, :course, :list_classes, nil)
    Class.list_classes()
  end

  @spec list_active_classes(Authentication.t()) :: list(Class.t())
  def list_active_classes(auth) do
    authorize!(auth, Policy, :course, :list_active_classes, nil)
    Class.list_active_classes(DateTime.to_date(Clock.now()))
  end

  # Subscribing to the classes topic grants no access beyond what `list_classes/1`
  # already authorized, so this read-model plumbing takes no authentication and
  # skips the authorization the command use cases perform.
  @spec subscribe_classes() :: :ok
  def subscribe_classes, do: PubSub.subscribe_classes()

  @spec refresh_classes(list(Class.t()), term()) :: {:ok, list(Class.t())} | :ignore
  def refresh_classes(classes, {:class_created, %Class{} = created}) when is_list(classes),
    do: {:ok, sort_classes([created | classes])}

  def refresh_classes(classes, {:class_updated, event, reference}) when is_list(classes) do
    id = class_updated_id(event)

    {:ok,
     classes
     |> Enum.map(fn
       %Class{id: ^id} = class -> Class.refresh!(class, event, reference)
       class -> class
     end)
     |> sort_classes()}
  end

  def refresh_classes(classes, {:class_deleted, %Class{id: id}}) when is_list(classes),
    do: {:ok, classes |> Enum.reject(&(&1.id == id)) |> sort_classes()}

  def refresh_classes(_classes, _message), do: :ignore

  defp class_updated_id(%ClassUpdated{id: id}), do: id
  defp class_updated_id(%ClassExpectedServerPropertiesUpdated{class: %{id: id}}), do: id

  defp sort_classes(classes),
    do: Enum.sort_by(classes, &{!&1.active, &1.end_date, &1.created_at, &1.name}, :desc)
end
