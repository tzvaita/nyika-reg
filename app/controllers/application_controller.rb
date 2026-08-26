class ApplicationController < ActionController::Base
  # PaperTrail records who made each change. It reads current_user by default,
  # but stating it explicitly keeps the audit trail from silently going anonymous
  # if authentication is ever restructured.
  before_action :set_paper_trail_whodunnit

  # CanCanCan raises this when a role is not permitted to do something; without a
  # handler it would surface as a 500 instead of a refusal.
  rescue_from CanCan::AccessDenied do |exception|
    redirect_back fallback_location: root_path, alert: exception.message
  end

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
