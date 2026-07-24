defmodule ArchiDepWeb.Admin.Classes.ImportStudentsDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDep.Helpers.DataHelpers, only: [looks_like_an_email?: 1]
  import ArchiDepWeb.Helpers.DialogHelpers
  import ArchiDepWeb.Components.FormComponents
  alias ArchiDep.Course
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.StudentView
  alias ArchiDepWeb.Admin.Classes.ImportStudentsCsv
  alias ArchiDepWeb.Admin.Classes.ImportStudentsForm
  alias ArchiDepWeb.Endpoint
  alias Phoenix.HTML.Form

  @id "import-students-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close, do: close_dialog(@id)

  @spec cell_class(Form.t(), atom(), String.t()) :: String.t()
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

  @spec state(Form.t(), map(), list(StudentView.t())) :: Rendered.t()
  def state(form, student, existing_students) do
    assigns = %{}

    if form.errors == [] do
      if student_exists?(form, student, existing_students) do
        ~H"""
        <div class="badge badge-neutral">{gettext("existing")}</div>
        """
      else
        ~H"""
        <div class="badge badge-success">{gettext("new")}</div>
        """
      end
    else
      ~H"""
      <div class="badge badge-warning">{gettext("invalid")}</div>
      """
    end
  end

  @spec student_exists?(Form.t(), map(), list(StudentView.t())) :: boolean()

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
      existing_students = Course.list_students(assigns.auth, assigns.class)

      socket
      |> assign(assigns)
      |> assign(uploaded_assigns(columns, students, existing_students))
      |> assign(:existing_students, existing_students)
      |> ok()
    else
      _anything_else ->
        socket
        |> assign(assigns)
        |> assign(
          state: :waiting_for_upload,
          columns: [],
          students: [],
          new_students: 0,
          existing_students: Course.list_students(assigns.auth, assigns.class)
        )
        |> ok()
    end
  end

  @impl LiveComponent
  def handle_event("closed", _params, socket) do
    {:noreply, socket}
  end

  @impl LiveComponent
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

  @impl LiveComponent
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

    case Changeset.apply_action(orig, :validate) do
      {:ok, _form_data} ->
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

      {:error, %Changeset{} = changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(changeset, action: :validate, as: :import_students),
           new_students: 0
         )}
    end
  end

  @impl LiveComponent
  def handle_event("validate", _params, socket) do
    # This validate clause is required to support live view file uploads.
    {:noreply, socket}
  end

  @impl LiveComponent
  def handle_event(
        "upload",
        _params,
        %Socket{assigns: %{existing_students: existing_students, state: state}} = socket
      )
      when state in [:waiting_for_upload, :invalid_upload] do
    parsed = consume_uploaded_students(socket)

    new_socket =
      case parsed do
        nil ->
          assign(socket, :state, :waiting_for_upload)

        [] ->
          assign(socket, :state, :invalid_upload)

        {:error, _error} ->
          assign(socket, :state, :invalid_upload)

        {:ok, %{columns: columns, students: students}} ->
          assign(socket, uploaded_assigns(columns, students, existing_students))
      end

    noreply(new_socket)
  end

  @impl LiveComponent
  def handle_event(
        "import",
        _params,
        %Socket{
          assigns: %{
            auth: auth,
            class: %ClassView{id: class_id},
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
      domain = form[:domain].value

      students_data =
        Enum.map(students, fn student ->
          %{
            name: student[name_column],
            email: student[email_column]
          }
        end)

      case Course.import_students(auth, class_id, %{
             academic_class: academic_class,
             domain: domain,
             students: students_data
           }) do
        {:ok, imported_students} ->
          socket
          |> assign(
            state: :waiting_for_upload,
            columns: [],
            students: [],
            new_students: 0
          )
          |> send_notification(
            Message.new(
              :success,
              gettext("{count, plural, =1 {1 student} other {# students}} imported",
                count: length(imported_students)
              )
            )
          )
          |> push_event("execute-action", %{to: "##{@id}", action: "close"})
          |> noreply()

        _anything_else ->
          noreply(socket)
      end
    else
      noreply(socket)
    end
  end

  defp uploaded_assigns(columns, students, existing_students) do
    %{email_column: email_column, name_column: name_column} =
      ImportStudentsCsv.detect_columns(columns, students)

    import_changeset =
      ImportStudentsForm.changeset(
        %{name_column: name_column, email_column: email_column},
        students
      )

    form = to_form(import_changeset, action: :validate, as: :import_students)

    new_students =
      if import_changeset.valid? do
        students
        |> Enum.filter(&(!student_exists?(form, &1, existing_students)))
        |> length()
      else
        0
      end

    [
      state: :uploaded,
      columns: columns,
      students: students,
      new_students: new_students,
      form: form
    ]
  end

  defp uploaded_students_file(%ClassView{id: class_id}),
    do: Path.join([uploads_directory(), "students", "classes", class_id, "import-students.csv"])

  defp consume_uploaded_students(socket),
    do:
      socket
      |> consume_uploaded_entries(:students, fn %{path: path}, _entry ->
        {:ok, parse_students_csv(path, uploaded_students_file(socket.assigns.class))}
      end)
      |> List.first()

  defp parse_students_csv(path, dest \\ nil) do
    case path |> File.stream!() |> ImportStudentsCsv.decode_students_csv() do
      {:ok, _decoded} = ok ->
        if dest do
          File.mkdir_p!(Path.dirname(dest))
          File.cp!(path, dest)
        end

        ok

      {:error, _reason} = error ->
        error
    end
  end

  defp uploads_directory,
    do: :archidep |> Application.fetch_env!(Endpoint) |> Keyword.fetch!(:uploads_directory)
end
