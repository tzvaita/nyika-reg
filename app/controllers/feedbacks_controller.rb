# "Have your say" — the second place the public can write, after /register.
#
# It creates a comment and nothing else: no household, no person, no link to any
# record. Someone may comment anonymously, because a complaint that can only be
# made under a name is not really an open channel.
class FeedbacksController < ApplicationController
  layout "public"

  rate_limit to: 5, within: 1.hour, only: :create, name: "feedback",
             with: -> { redirect_to have_your_say_path,
                        alert: "Thank you — we already have your comment." }

  def new
    @feedback = Feedback.new
  end

  def create
    # Honeypot: a field no person sees. Silently succeed so a bot learns nothing.
    return render :created if params[:website].present?

    @feedback = Feedback.new(feedback_params)
    @feedback.change_reason = "Sent from the public website"
    @feedback.audit_source_channel = "public_site"

    if @feedback.save
      render :created, status: :created
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feedback_params
    params.require(:feedback).permit(:name, :contact_method, :category, :message)
  end

  def audit_source_channel
    "public_site"
  end
end
