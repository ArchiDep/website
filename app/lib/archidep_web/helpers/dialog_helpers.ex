defmodule ArchiDepWeb.Helpers.DialogHelpers do
  @moduledoc """
  Helper functions for managing modal dialog interactions.
  """

  import Phoenix.Component, only: [assign: 2, to_form: 2]
  alias Ecto.Changeset
  alias Phoenix.LiveView.Socket
  alias Phoenix.LiveView.JS

  def close_dialog(id) do
    %JS{}
    |> JS.push("closed", target: "##{id}")
    |> JS.dispatch("phx:close-dialog", detail: %{dialog: id})
  end

  @spec validate_dialog_form(
          atom,
          Changeset.t(),
          (Changeset.t() -> {:ok, Changeset.t()} | {:error, term}),
          Socket.t()
        ) :: {:noreply, Socket.t()}
  def validate_dialog_form(name, validate_changeset, validate, socket) do
    with {:ok, form_data} <-
           Changeset.apply_action(validate_changeset, :validate),
         {:ok, changeset} <- validate.(form_data) do
      {:noreply, assign(socket, form: to_form(changeset, as: name, action: :validate))}
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: name))}
    end
  end
end
