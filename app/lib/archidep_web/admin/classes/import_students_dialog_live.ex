defmodule ArchiDepWeb.Admin.Classes.ImportStudentsDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDep.Helpers.DataHelpers, only: [looks_like_an_email?: 1]
  import ArchiDepWeb.Helpers.DialogHelpers
  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Students
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDepWeb.Admin.Classes.ImportStudentsForm
  alias Phoenix.HTML.Form

  @id "import-students-dialog"
  @uploads_directory Application.compile_env!(:archidep, [
                       ArchiDepWeb.Endpoint,
                       :uploads_directory
                     ])

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close(), do: close_dialog(@id)

  def cell_class(form, column, value) do
    name_column = form[:name_column].value
    name_column_valid = !Keyword.has_key?(form.errors, :name_column)

    email_column = form[:email_column].value
    email_column_valid = !Keyword.has_key?(form.errors, :email_column)

    cond do
      column == name_column and value != "" and name_column_valid ->
        "text-success"

      column == email_column and looks_like_an_email?(value) and email_column_valid ->
        "text-success"

      true ->
        "text-base-content/50"
    end
  end

  def state(form, student, existing_students) do
    assigns = %{}

    if form.errors == [] do
      if student_exists?(form, student, existing_students) do
        ~H"""
        <div class="badge badge-neutral">existing</div>
        """
      else
        ~H"""
        <div class="badge badge-success">new</div>
        """
      end
    else
      ~H"""
      <div class="badge badge-warning">invalid</div>
      """
    end
  end

  def student_exists?(%Form{errors: []} = form, student, existing_students) do
    email_column = form[:email_column].value

    Enum.any?(existing_students, fn existing_student ->
      String.downcase(existing_student.email) == String.downcase(student[email_column])
    end)
  end

  def student_exists?(_form, _student, _existing_students) do
    false
  end

  @impl LiveComponent
  def mount(socket) do
    socket
    |> allow_upload(:students, accept: ~w(.csv), max_entries: 1, max_file_size: 100_000)
    |> ok()
  end

  @impl LiveComponent
  def update(assigns, socket) do
    file = uploaded_students_file(assigns.class)

    with true <- File.exists?(file),
         {:ok, %{columns: columns, students: students}} <- parse_students_csv(file) do
      email_column_candidate =
        columns
        |> Enum.map(fn col ->
          {col,
           Enum.count(students, fn student ->
             student |> Map.get(col, "") |> String.contains?("@")
           end)}
        end)
        |> Enum.sort_by(fn {_col, count} -> -count end)
        |> Enum.map(&elem(&1, 0))
        |> Enum.at(0)

      name_column_candidate =
        Enum.at(columns, if(email_column_candidate == List.first(columns), do: 1, else: 0))

      import_changeset =
        ImportStudentsForm.changeset(
          %{
            name_column: name_column_candidate,
            email_column: email_column_candidate
          },
          students
        )

      form =
        to_form(
          import_changeset,
          action: :validate,
          as: :import_students
        )

      existing_students = Students.list_students(assigns.auth, assigns.class)

      socket
      |> assign(assigns)
      |> assign(
        state: :uploaded,
        columns: columns,
        students: students,
        new_students:
          if(import_changeset.valid?,
            do:
              students
              |> Enum.filter(&(!student_exists?(form, &1, existing_students)))
              |> length(),
            else: 0
          ),
        form: form,
        existing_students: existing_students
      )
      |> ok()
    else
      _ ->
        socket
        |> assign(assigns)
        |> assign(
          state: :waiting_for_upload,
          columns: [],
          students: [],
          new_students: 0,
          existing_students: Students.list_students(assigns.auth, assigns.class)
        )
        |> ok()
    end
  end

  @impl LiveComponent

  def handle_event("closed", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("clear", _params, %Socket{assigns: %{state: :uploaded}} = socket) do
    file = uploaded_students_file(socket.assigns.class)
    File.rm!(file)

    {:noreply,
     assign(socket,
       state: :waiting_for_upload,
       columns: [],
       students: [],
       new_students: 0
     )}
  end

  def handle_event(
        "validate",
        %{"import_students" => params},
        %Socket{
          assigns: %{
            existing_students: existing_students,
            form: form,
            state: :uploaded,
            students: students
          }
        } = socket
      ) do
    orig = ImportStudentsForm.changeset(params, students)

    with {:ok, _form_data} <-
           Changeset.apply_action(orig, :validate) do
      {:noreply,
       assign(socket,
         form: to_form(orig, action: :validate, as: :import_students),
         new_students:
           if(orig.valid?,
             do:
               students
               |> Enum.filter(&(!student_exists?(form, &1, existing_students)))
               |> length(),
             else: 0
           )
       )}
    else
      {:error, %Changeset{} = changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(changeset, action: :validate, as: :import_students),
           new_students: 0
         )}
    end
  end

  def handle_event("validate", _params, socket) do
    # This validate clause is required to support live view file uploads.
    {:noreply, socket}
  end

  def handle_event(
        "upload",
        _params,
        %Socket{assigns: %{existing_students: existing_students, state: state}} = socket
      )
      when state in [:waiting_for_upload, :invalid_upload] do
    parsed = consume_uploaded_students(socket)

    case parsed do
      nil ->
        assign(socket, :state, :waiting_for_upload)

      [] ->
        assign(socket, :state, :invalid_upload)

      {:error, _error} ->
        assign(socket, :state, :invalid_upload)

      {:ok, %{columns: columns, students: students}} ->
        email_column_candidate =
          columns
          |> Enum.map(fn col ->
            {col,
             Enum.count(students, fn student ->
               student |> Map.get(col, "") |> String.contains?("@")
             end)}
          end)
          |> Enum.sort_by(fn {_col, count} -> -count end)
          |> Enum.map(&elem(&1, 0))
          |> Enum.at(0)

        name_column_candidate =
          Enum.at(columns, if(email_column_candidate == List.first(columns), do: 1, else: 0))

        import_changeset =
          ImportStudentsForm.changeset(
            %{
              name_column: name_column_candidate,
              email_column: email_column_candidate
            },
            students
          )

        form =
          to_form(
            import_changeset,
            action: :validate,
            as: :import_students
          )

        assign(socket,
          state: :uploaded,
          students: students,
          new_students:
            if(import_changeset.valid?,
              do:
                students
                |> Enum.filter(&(!student_exists?(form, &1, existing_students)))
                |> length(),
              else: 0
            ),
          columns: columns,
          form: form
        )
    end
    |> noreply()
  end

  def handle_event(
        "import",
        _params,
        %Socket{
          assigns: %{
            auth: auth,
            class: %Class{id: class_id},
            state: :uploaded,
            form: form,
            students: students
          }
        } = socket
      ) do
    if Enum.empty?(form.errors) do
      name_column = form[:name_column].value
      email_column = form[:email_column].value
      academic_class = form[:academic_class].value

      students_data =
        Enum.map(students, fn student ->
          %{
            name: student[name_column],
            email: student[email_column]
          }
        end)

      with {:ok, _students} <-
             Students.import_students(auth, class_id, %{
               academic_class: academic_class,
               students: students_data
             }) do
        socket
        |> push_event("execute-action", %{to: "##{@id}", action: "close"})
        |> noreply()
      else
        _ ->
          noreply(socket)
      end
    else
      noreply(socket)
    end
  end

  defp uploaded_students_file(%Class{id: class_id}),
    do: Path.join([@uploads_directory, "students", "classes", class_id, "import-students.csv"])

  defp consume_uploaded_students(socket),
    do:
      consume_uploaded_entries(socket, :students, fn %{path: path}, _entry ->
        {:ok, parse_students_csv(path, uploaded_students_file(socket.assigns.class))}
      end)
      |> List.first()

  defp parse_students_csv(path, dest \\ nil) do
    headers =
      path
      |> File.stream!()
      |> CSV.decode(
        field_transform: &String.trim/1,
        headers: false
      )
      |> Enum.filter(fn
        {:ok, _row} -> true
        _ -> false
      end)
      |> Enum.reduce([], fn
        {:ok, row}, acc -> [row | acc]
        _, acc -> acc
      end)
      |> Enum.reverse()
      |> Enum.take(1)
      |> Enum.flat_map(&Function.identity/1)
      |> Enum.filter(fn col -> col != "" end)

    students =
      path
      |> File.stream!()
      |> CSV.decode(
        field_transform: &String.trim/1,
        headers: true
      )
      |> Enum.filter(fn
        {:ok, _row} -> true
        _ -> false
      end)
      |> Enum.reduce([], fn
        {:ok, row}, acc -> [Map.filter(row, fn {key, _val} -> key != "" end) | acc]
        _, acc -> acc
      end)
      |> Enum.reverse()
      |> Enum.to_list()

    cond do
      length(headers) < 2 ->
        {:error, :not_enough_columns}

      length(students) < 1 ->
        {:error, :no_valid_rows}

      true ->
        if dest do
          File.mkdir_p!(Path.dirname(dest))
          File.cp!(path, dest)
        end

        {:ok, %{columns: headers, students: students}}
    end
  end
end
