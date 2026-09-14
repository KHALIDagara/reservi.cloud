module ApplicationHelper
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
