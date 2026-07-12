module ApplicationHelper
  # Returns the class list for a nav link, marking it active when the
  # current request path is at (or under) `path`. Root path only matches
  # exactly to avoid highlighting Live for every URL.
  def nav_link_classes(path)
    base = "nav-link"
    return base if path.nil?

    current = if path == root_path
      request.path == root_path
    else
      request.path == path || request.path.start_with?("#{path}/")
    end

    current ? "#{base} nav-link--active" : base
  end
end
