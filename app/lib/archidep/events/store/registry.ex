defmodule ArchiDep.Events.Store.Registry do
  @moduledoc """
  Defines an event registry.

      defmodule ArchiDep.Events do
        use ArchiDep.Events.Store.Registry
        event(SomethingHappened, prefix: "something:", by: :id, type: :something)
      end
  """

  @type t :: module

  @doc """
  Returns the stream an event is part of.
  """
  @callback event_stream(struct) :: String.t()

  @doc """
  Returns the type of an event.
  """
  @callback event_type(struct) :: String.t()

  @doc """
  Deserializes stored event data into the correct struct.
  """
  @callback deserialize(struct, String.t()) :: struct

  @spec __using__(any) :: Macro.t()
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)

      @before_compile unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :registered_identities, accumulate: false)

      @registered_identities %{}
    end
  end

  @doc """
  Registers an event struct.
  """
  @spec event(atom, keyword) :: Macro.t()
  defmacro event(module, opts! \\ []) do
    {prefix, opts!} = Keyword.pop(opts!, :prefix, "")
    {by, opts!} = Keyword.pop!(opts!, :by)
    {type, opts!} = Keyword.pop!(opts!, :type)
    [] = opts!

    quote do
      @registered_identities Map.put(@registered_identities, unquote(module),
                               prefix: unquote(prefix),
                               by: unquote(by),
                               type: unquote(type)
                             )
    end
  end

  @spec __before_compile__(any) :: Macro.t()
  # credo:disable-for-next-line /Credo.Check.Refactor.(ABCSize|CyclomaticComplexity)/
  defmacro __before_compile__(_env) do
    quote generated: true do
      @behaviour ArchiDep.Events.Store.Registry

      alias Ecto.UUID
      alias ArchiDep.Events.Store.Registry.Utils
      alias ArchiDep.Events.Store.StoredEvent

      @doc """
      Returns the stream an event is part of.
      """
      @spec event_stream(struct) :: String.t()
      def event_stream(struct)

      @doc """
      Returns the type of an event.
      """
      @spec event_type(struct) :: String.t()
      def event_type(struct)

      @doc """
      Deserializes stored event data into the correct struct.
      """
      @spec deserialize(struct, String.t()) :: struct
      def deserialize(event_data, event_type)

      for {module, opts} <- @registered_identities do
        @module module
        @event_stream_prefix Keyword.fetch!(opts, :prefix)
        @event_stream_by Keyword.fetch!(opts, :by)
        @event_type Keyword.fetch!(opts, :type)
        @event_type_string Atom.to_string(@event_type)

        def event_stream(%@module{} = event) do
          "#{@event_stream_prefix}#{Map.get(event, @event_stream_by)}"
        end

        def event_type(%@module{} = event) do
          Atom.to_string(@event_type)
        end

        def deserialize(event_data, @event_type_string) when is_struct(event_data, @module) do
          event_data
        end

        def deserialize(event_data, @event_type_string) when is_map(event_data) do
          struct!(
            @module,
            Keyword.new(event_data, fn
              {key, value} when is_atom(key) ->
                {key, value}

              {key, value} when is_binary(key) ->
                {String.to_existing_atom(key), value}
            end)
          )
        end
      end

      @doc """
      Deserialized a stored event's data into the correct struct.
      """
      @spec deserialize(StoredEvent.t(struct)) :: struct
      def deserialize(%StoredEvent{} = stored_event) do
        Utils.deserialize(__MODULE__, stored_event)
      end
    end
  end
end
