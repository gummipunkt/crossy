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
end
