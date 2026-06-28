defmodule ArchiDepWeb.Helpers.DialogHelpersTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [to_form: 2]
  alias ArchiDepWeb.Helpers.DialogHelpers
  alias Ecto.Changeset
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Socket

  describe "open_dialog/1" do
    test "pushes the opened event to the dialog and dispatches the open-dialog event" do
      assert DialogHelpers.open_dialog("my-dialog") ==
               %JS{}
               |> JS.push("opened", target: "#my-dialog")
               |> JS.dispatch("open-dialog", detail: %{dialog: "my-dialog"})
    end
  end

  describe "close_dialog/1" do
    test "pushes the closed event to the dialog and dispatches the phx:close-dialog event" do
      assert DialogHelpers.close_dialog("my-dialog") ==
               %JS{}
               |> JS.push("closed", target: "#my-dialog")
               |> JS.dispatch("phx:close-dialog", detail: %{dialog: "my-dialog"})
    end
  end

  describe "validate_dialog_form/4" do
    test "assigns the validate-actioned form built from the validating function's changeset on success" do
      validated_changeset = name_changeset(%{"name" => "validated"})

      result =
        DialogHelpers.validate_dialog_form(
          :dialog_form,
          name_changeset(%{"name" => "draft"}),
          fn _form_data -> {:ok, validated_changeset} end,
          new_socket()
        )

      assert assigned_form(result) ==
               to_form(validated_changeset, as: :dialog_form, action: :validate)
    end

    test "assigns the form built from the invalid changeset when the data cannot be applied" do
      invalid_changeset = name_changeset(%{})
      {:error, errored_changeset} = Changeset.apply_action(invalid_changeset, :validate)

      result =
        DialogHelpers.validate_dialog_form(
          :dialog_form,
          invalid_changeset,
          fn _form_data -> flunk("the validating function must not run on invalid data") end,
          new_socket()
        )

      assert assigned_form(result) == to_form(errored_changeset, as: :dialog_form)
    end

    test "assigns the form built from the validating function's changeset on its error" do
      error_changeset = name_changeset(%{})

      result =
        DialogHelpers.validate_dialog_form(
          :dialog_form,
          name_changeset(%{"name" => "draft"}),
          fn _form_data -> {:error, error_changeset} end,
          new_socket()
        )

      assert assigned_form(result) == to_form(error_changeset, as: :dialog_form)
    end
  end

  defp new_socket, do: %Socket{assigns: %{__changed__: %{}}}

  defp assigned_form({:noreply, %Socket{assigns: %{form: form}}}), do: form

  defp name_changeset(params),
    do:
      {%{}, %{name: :string}}
      |> Changeset.cast(params, [:name])
      |> Changeset.validate_required([:name])
end
