module ApplicationHelper
  # Active state for main nav pills (Turbo-aware).
  def nav_pill_class(active)
    base = "inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium transition-all duration-200 "
    if active
      "#{base} bg-gradient-to-r from-violet-400 to-purple-400 text-violet-950 shadow-md shadow-violet-400/35 border border-violet-300/50"
    else
      "#{base} text-stone-600 hover:bg-stone-100/90 hover:text-stone-900"
    end
  end

  def composer_nav_active?
    controller_name == "posts" && action_name == "new"
  end

  def timeline_nav_active?
    controller_name == "feeds"
  end

  def my_posts_nav_active?
    controller_name == "timeline"
  end

  def networks_nav_active?
    controller_name == "provider_accounts"
  end

  def admin_nav_active?
    controller_path.start_with?("admin/")
  end

  def notifications_nav_active?
    controller_name == "notifications"
  end

  # Consistent color treatment per network across all pages.
  def network_badge_class(provider)
    base = "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold border "
    base + case provider.to_s
    when "mastodon" then "border-green-200/90 bg-green-100/80 text-green-900"
    when "bluesky"  then "border-sky-200/90 bg-sky-100/80 text-sky-900"
    when "threads"  then "border-amber-200/90 bg-amber-100/80 text-amber-900"
    when "nostr"    then "border-pink-200/90 bg-pink-100/80 text-pink-900"
    else                 "border-violet-200/90 bg-violet-100/70 text-violet-900"
    end
  end

  def network_label(provider)
    provider.to_s.capitalize
  end
end
