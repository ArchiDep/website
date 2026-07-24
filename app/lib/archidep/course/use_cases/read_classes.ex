defmodule ArchiDep.Course.UseCases.ReadClasses do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Clock
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Events.ClassCreated
  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Events.Store.EventReference

  @spec fetch_class(Authentication.t() | nil, UUID.t()) ::
          {:ok, ClassView.t()} | {:error, :class_not_found}
  def fetch_class(auth, id) do
    with :ok <- validate_uuid(id, :class_not_found),
         {:ok, class} <- Class.fetch_class(id),
         :ok <- authorize(auth, Policy, :course, :fetch_class, class) do
      {:ok, ClassView.from(class)}
    else
      {:error, :class_not_found} ->
        {:error, :class_not_found}

      {:error, {:access_denied, :course, :fetch_class}} ->
        {:error, :class_not_found}
    end
  end

  @spec list_classes(Authentication.t()) :: list(ClassView.t())
  def list_classes(auth) do
    authorize!(auth, Policy, :course, :list_classes, nil)
    Enum.map(Class.list_classes(), &ClassView.from/1)
  end

  @spec list_active_classes(Authentication.t()) :: list(ClassView.t())
  def list_active_classes(auth) do
    authorize!(auth, Policy, :course, :list_active_classes, nil)

    Clock.now()
    |> DateTime.to_date()
    |> Class.list_active_classes()
    |> Enum.map(&ClassView.from/1)
  end

  # Subscribing to the classes topic grants no access beyond what
  # `list_classes/1` already authorized, so subscribing takes no authentication
  # and skips the authorization the command use cases perform.
  @spec subscribe_classes() :: :ok
  def subscribe_classes, do: PubSub.subscribe_classes()

  @spec refresh_classes(Authentication.t() | nil, list(ClassView.t()), term()) ::
          {:ok, list(ClassView.t())} | :ignore
  def refresh_classes(auth, classes, {:class_created, %ClassCreated{id: id}, %EventReference{}})
      when is_list(classes) do
    # The created broadcast carries only the curated event, so fetch the full
    # read-view on first sighting. This goes through the public context boundary
    # rather than the local read so the consuming LiveView sees it as an
    # ordinary context read (authorized, and mockable) like every other class
    # fetch.
    case ArchiDep.Course.fetch_class(auth, id) do
      {:ok, %ClassView{} = created} -> {:ok, sort_classes([created | classes])}
      {:error, :class_not_found} -> {:ok, classes}
    end
  end

  def refresh_classes(_auth, classes, {:class_updated, event, reference}) when is_list(classes) do
    id = class_updated_id(event)

    {:ok,
     classes
     |> Enum.map(fn
       %ClassView{id: ^id} = class -> ClassView.refresh!(class, event, reference)
       class -> class
     end)
     |> sort_classes()}
  end

  def refresh_classes(_auth, classes, {:class_deleted, %ClassDeleted{id: id}, %EventReference{}})
      when is_list(classes),
      do: {:ok, classes |> Enum.reject(&(&1.id == id)) |> sort_classes()}

  def refresh_classes(_auth, _classes, _message), do: :ignore

  # Subscribing to the topic of a class the caller already holds grants no new
  # access, so this read-model plumbing takes no authentication and skips the
  # authorization the command use cases perform.
  @spec subscribe_class(ClassView.t()) :: :ok
  def subscribe_class(%ClassView{id: id}), do: PubSub.subscribe_class(id)

  @spec refresh_class(ClassView.t() | nil, term()) :: {:ok, ClassView.t()} | :ignore
  def refresh_class(%ClassView{id: id} = class, {:class_updated, event, reference}) do
    if class_updated_id(event) == id do
      {:ok, ClassView.refresh!(class, event, reference)}
    else
      :ignore
    end
  end

  def refresh_class(_class, _message), do: :ignore

  defp class_updated_id(%ClassUpdated{id: id}), do: id
  defp class_updated_id(%ClassExpectedServerPropertiesUpdated{class: %{id: id}}), do: id

  defp sort_classes(classes),
    do: Enum.sort_by(classes, &{!&1.active, &1.end_date, &1.created_at, &1.name}, :desc)
end
