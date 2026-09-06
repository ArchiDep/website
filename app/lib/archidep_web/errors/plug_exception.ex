# What HTTP status the errors raised by the business layer are answered with.
#
# `Plug.Exception` reads a `:plug_status` field off the exception when there is
# no implementation for it, which is why an unmapped error is a 500. That field
# would put an HTTP concept on a struct the contexts raise and the web layer
# merely happens to see, so the mapping is stated here instead, where HTTP is —
# the same place, and for the same reason, that `phoenix_ecto` maps
# `Ecto.NoResultsError` to a 404.
defimpl Plug.Exception, for: ArchiDep.Errors.UnauthorizedError do
  # The caller is authenticated (an anonymous one never reaches a policy: the
  # auth plug and the on_mount hook send them to the login page first), so what
  # failed is permission, not identity. Nothing about the request will make it
  # succeed, which is a 403 and not a 401.
  @spec status(ArchiDep.Errors.UnauthorizedError.t()) :: 403
  def status(_exception), do: 403

  @spec actions(ArchiDep.Errors.UnauthorizedError.t()) :: []
  def actions(_exception), do: []
end
