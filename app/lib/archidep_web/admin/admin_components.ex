defmodule ArchiDepWeb.Admin.AdminComponents do
  use ArchiDepWeb, :component

  alias ArchiDep.Servers.Schemas.ServerGroupMember

  attr :server_group_member, ServerGroupMember,
    default: nil,
    doc: "the server group member whose username to display"

  attr :suggested_username, :string,
    required: true,
    doc: "the suggested username if the member does not yet have one"

  def server_username(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:items-center gap-x-2">
      <span class="font-mono">
        <%= if @server_group_member != nil and @server_group_member.username do %>
          {@server_group_member.username}
        <% else %>
          {@suggested_username}
        <% end %>
      </span>
      <span
        :if={@server_group_member == nil or @server_group_member.username == nil}
        class="text-xs italic text-base-content/50"
      >
        ({gettext("suggested")})
      </span>
    </div>
    """
  end

  @spec server_fqdn(ServerGroupMember.t() | nil, String.t(), String.t()) :: String.t()
  def server_fqdn(nil, suggested_username, base_domain),
    do: "#{suggested_username}.#{base_domain}"

  def server_fqdn(%ServerGroupMember{subdomain: nil}, suggested_username, base_domain),
    do: "#{suggested_username}.#{base_domain}"

  def server_fqdn(%ServerGroupMember{subdomain: subdomain}, _suggested_username, base_domain),
    do: "#{subdomain}.#{base_domain}"
end
