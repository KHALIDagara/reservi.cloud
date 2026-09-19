module ApplicationHelper
  NAV_ICON_PATHS = {
    home: '<path stroke-linecap="round" stroke-linejoin="round" d="m2.25 12 8.954-8.955a1.125 1.125 0 0 1 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75"/>',
    inbox: '<path stroke-linecap="round" stroke-linejoin="round" d="M2.25 13.5h3.86a2.25 2.25 0 0 1 2.012 1.244l.256.512a2.25 2.25 0 0 0 2.013 1.244h3.218a2.25 2.25 0 0 0 2.013-1.244l.256-.512A2.25 2.25 0 0 1 17.89 13.5h3.86m-19.5 0 2.483-8.69A2.25 2.25 0 0 1 6.896 3.18h10.208a2.25 2.25 0 0 1 2.163 1.632l2.483 8.69v5.25A2.25 2.25 0 0 1 19.5 21h-15a2.25 2.25 0 0 1-2.25-2.25V13.5Z"/>',
    calendar: '<path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5"/>',
    users: '<path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.205-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z"/>',
    flow: '<path stroke-linecap="round" stroke-linejoin="round" d="M6 3.75H4.875c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125H6m0-3.75h12m-12 0v3.75m12-3.75h1.125c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125H18m0-3.75v3.75m-12 0h12M6 7.5v3.75m12-3.75v3.75M6 15h12m-12 0H4.875c-.621 0-1.125.504-1.125 1.125v3c0 .621.504 1.125 1.125 1.125H6m0-5.25v5.25m12-5.25h1.125c.621 0 1.125.504 1.125 1.125v3c0 .621-.504 1.125-1.125 1.125H18m0-5.25v5.25m-12 0h12M9 11.25h6v3.75H9v-3.75Z"/>',
    catalog: '<path stroke-linecap="round" stroke-linejoin="round" d="m21 8.25-9-4.5-9 4.5m18 0-9 4.5m9-4.5v7.5l-9 4.5m0-7.5-9-4.5m9 4.5v7.5m-9-12v7.5l9 4.5"/>',
    fields: '<path stroke-linecap="round" stroke-linejoin="round" d="M9.568 3H5.25A2.25 2.25 0 0 0 3 5.25v13.5A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V8.432m-11.432 0 6.92-6.92a1.875 1.875 0 1 1 2.652 2.652l-6.92 6.92a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897Z"/>',
    plus: '<path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>',
    building: '<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21"/>',
    logout: '<path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9"/>',
    robot: '<path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5V3.75a2.25 2.25 0 0 1 2.25-2.25h3a2.25 2.25 0 0 1 2.25 2.25v.75m-9 0h9m-9 0a2.25 2.25 0 0 0-2.25 2.25v9a2.25 2.25 0 0 0 2.25 2.25h9a2.25 2.25 0 0 0 2.25-2.25v-9a2.25 2.25 0 0 0-2.25-2.25m-6.75 6.75h4.5m-2.25-3v6"/>'
  }.freeze

  def app_icon(name, class_name: "size-5")
    content_tag(:svg, NAV_ICON_PATHS.fetch(name).html_safe,
      class: class_name, fill: "none", viewBox: "0 0 24 24",
      stroke: "currentColor", "stroke-width": "1.75", "aria-hidden": "true")
  end

  def app_nav_active?(section)
    case section
    when :home then controller_path == "accounts/home"
    when :inbox then controller_path.in?([ "accounts/inboxes", "accounts/inboxes/conversations", "accounts/inboxes/conversations/messages", "accounts/inboxes/conversations/notes", "accounts/inboxes/conversations/panel", "accounts/conversations" ])
    when :calendar then controller_path.in?([ "accounts/calendar", "accounts/calendar_settings", "accounts/calendar_exceptions" ])
    when :channels then controller_path.in?([ "accounts/inboxes", "accounts/channels" ])
    when :people then controller_path.in?([ "accounts/people", "accounts/invitations", "accounts/memberships" ])
    when :ai_agents then controller_path.in?([ "accounts/ai_agents", "accounts/ai_agents/activations", "accounts/ai_agents/previews" ])
    when :flows then controller_path.in?([ "accounts/flows", "accounts/flow_versions", "accounts/stages" ])
    when :catalogs then controller_path.in?([ "accounts/catalogs", "accounts/item_selections" ])
    when :fields then controller_path.in?([ "accounts/field_definitions", "accounts/customer_fields" ])
    else false
    end
  end

  # Returns an avatar initial for an agent (fallback when no real avatar exists).
  def avatar_for_agent(agent)
    return nil unless agent
    # In a real app this would return a processed avatar URL.
    # For now return the initial + a color hint for client-side rendering.
    nil
  end

  # Returns a Tailwind CSS color class for delivery status indicators.
  def delivery_status_color(status)
    case status
    when "sent", "delivered" then "text-green-600"
    when "pending", "sending" then "text-amber-500"
    when "failed" then "text-red-600"
    when "unknown" then "text-stone-400"
    when "received" then "text-blue-600"
    else "text-stone-400"
    end
  end

  # Returns an icon character (emoji-free) for delivery status.
  def delivery_status_icon(status)
    case status
    when "sent" then "✓"
    when "delivered" then "✓✓"
    when "pending", "sending" then "○"
    when "failed" then "✕"
    when "unknown" then "?"
    when "received" then "↓"
    else "·"
    end
  end
end
