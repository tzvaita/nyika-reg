module Whatsapp
  # Turns an inbound message into an action and a reply.
  #
  # The single place a chat becomes a change to the registry. Every rule it
  # applies belongs to a model — it calls `record_resident_update!`,
  # `ProgrammeCase`, `Contribution` and the consent model rather than
  # reimplementing any of them, so WhatsApp cannot drift from the web.
  #
  # Two things it will not do:
  #   * create a case without explicit consent, exactly as the web form behaves;
  #   * confirm anything a resident cannot confirm on the web — a pledge stays a
  #     pledge, an update goes back to the verification queue.
  class Router
    MENU = <<~TEXT.strip
      Nyika Village Registry. Reply with a number:
      1 Update my household
      2 Government support
      3 Make a payment
      4 My applications
      5 My receipts
      6 Speak to the village office

      Reply STOP at any time to end.
    TEXT

    STOP_WORDS = %w[stop cancel end quit exit].freeze
    MENU_WORDS = %w[menu hi hello start help].freeze

    def initialize(inbound_message)
      @inbound = inbound_message
      @conversation = inbound_message.conversation
      @text = inbound_message.text
    end

    def call
      # Expiry is checked BEFORE the message is counted — touching it first would
      # mean a session could never lapse, and a flow abandoned yesterday would
      # quietly resume with stale answers.
      if @conversation.expired? && @conversation.in_flow?
        @conversation.reset!
        @lapsed = true
      end
      @conversation.touch_message!

      @conversation.resolve_household!.save!
      @inbound.update!(household: @conversation.household)

      reply_body = route
      record(reply_body)
    end

    private

    attr_reader :conversation, :text

    def household = conversation.household

    def route
      return handle_stop if STOP_WORDS.include?(text.downcase)
      return handle_menu_request if MENU_WORDS.include?(text.downcase)
      # Someone answering a question we asked an hour ago should not have that
      # answer silently read as a menu choice and start something else entirely.
      return handle_lapsed_session if @lapsed

      if conversation.in_flow?
        continue_flow
      elsif household
        handle_menu_choice
      else
        start_registration
      end
    end

    # --- stranger: registration ------------------------------------------

    def start_registration
      conversation.advance!("registering_name")
      handled("registration_started")
      <<~TEXT.strip
        Hello. This number is not on the village register.

        If you would like your household registered, reply with your NAME and
        the village office will get in touch. Reply STOP to end.
      TEXT
    end

    def continue_registration_name
      conversation.advance!("registering_location", name: text)
      handled("registration_name")
      "Thank you, #{text}. Where can we find you? Describe it as you would to a neighbour."
    end

    def finish_registration
      request = RegistrationRequest.create!(
        name: conversation.context["name"],
        contact_number: conversation.contact_number,
        contact_method: conversation.contact_number,
        location_hint: text,
        note: "Sent by WhatsApp",
        change_reason: "Requested over WhatsApp",
        audit_source_channel: "whatsapp"
      )
      conversation.reset!
      handled("registration_request_created", "created #{request.name}")

      <<~TEXT.strip
        Thank you. The village office has your request and will come and see you.

        Nothing about your household has been recorded yet — that happens when
        you have spoken to someone and agreed to it.
      TEXT
    end

    # --- known household: the menu ----------------------------------------

    def handle_menu_choice
      case text
      when "1" then begin_update
      when "2" then begin_support
      when "3" then begin_payment
      when "4" then show_applications
      when "5" then show_receipts
      when "6" then show_office
      else MENU
      end
    end

    def begin_update
      conversation.advance!("updating_contact")
      handled("update_started")
      "What has changed? Reply with the new phone number or a description of " \
      "where to find you, and the village office will confirm it."
    end

    def apply_update
      household.principal_contact = text
      household.record_resident_update!(reason: "Updated over WhatsApp")
      conversation.reset!
      handled("household_updated")

      "Thank you. Your change has been sent to the village office to confirm. " \
      "Reply MENU for anything else."
    end

    def begin_support
      conversation.advance!("support_choosing_programme")
      handled("support_started")
      programmes = ProgrammeCase.programme_types.keys.each_with_index
                                .map { |type, i| "#{i + 1} #{type.humanize}" }.join("\n")
      "What kind of support are you asking about?\n#{programmes}"
    end

    def choose_programme
      index = text.to_i - 1
      programme = ProgrammeCase.programme_types.keys[index] if index >= 0

      return "Please reply with a number from the list, or STOP to end." if programme.blank?

      members = household.active_people.to_a
      conversation.advance!("support_choosing_member", programme_type: programme)
      handled("support_programme_chosen", programme)

      list = members.each_with_index.map { |m, i| "#{i + 1} #{m.name}" }.join("\n")
      "Who is it for?\n#{list}\n0 The whole household"
    end

    def choose_member
      members = household.active_people.to_a
      index = text.to_i

      beneficiary_id = index.positive? ? members[index - 1]&.id : nil
      return "Please reply with a number from the list." if index.positive? && beneficiary_id.blank?

      conversation.advance!("support_confirming_consent", beneficiary_id: beneficiary_id)
      handled("support_member_chosen")

      <<~TEXT.strip
        Before we can open a request we need your agreement:

        "#{ConsentRecord::PURPOSE_DESCRIPTIONS['programme']}"

        Reply YES to agree, or STOP to end.
      TEXT
    end

    # Consent is never assumed from asking. No YES, no case — the same rule the
    # web form applies, and the message that says YES is kept as the evidence.
    def confirm_support_consent
      unless text.downcase.start_with?("y")
        conversation.reset!
        handled("support_consent_declined")
        return "No request has been opened. Reply MENU if you would like anything else."
      end

      programme = conversation.context["programme_type"]
      beneficiary = household.active_people.find_by(id: conversation.context["beneficiary_id"])

      existing = open_case_for(programme, beneficiary)
      if existing
        conversation.reset!
        handled("support_duplicate_avoided", existing.reference)
        return "You already have a request for #{programme.humanize} " \
               "(#{existing.reference}). It is #{existing.status.humanize.downcase}. " \
               "Reply 4 to see your applications."
      end

      programme_case = ActiveRecord::Base.transaction do
        record_programme_consent(beneficiary)
        created = ProgrammeCase.create!(
          household: household, beneficiary: beneficiary, programme_type: programme,
          change_reason: "Requested over WhatsApp", audit_source_channel: "whatsapp"
        )
        created.refresh_stage!(reason: "Opened from a WhatsApp request")
        created
      end

      conversation.reset!
      handled("support_case_created", programme_case.reference)

      "Thank you. Your request has been sent to the village office (#{programme_case.reference}). " \
      "They will tell you what is needed."
    end

    def begin_payment
      campaigns = MobilisationCampaign.live.order(:opens_on).to_a
      if campaigns.empty?
        handled("payment_none_open")
        return "There are no collections open at the moment. Reply MENU for anything else."
      end

      conversation.advance!("paying_choosing_campaign")
      handled("payment_started")
      list = campaigns.each_with_index.map { |c, i| "#{i + 1} #{c.name}" }.join("\n")
      "Which collection?\n#{list}"
    end

    def choose_campaign
      campaigns = MobilisationCampaign.live.order(:opens_on).to_a
      campaign = campaigns[text.to_i - 1]
      return "Please reply with a number from the list." if campaign.blank?

      conversation.advance!("paying_amount", campaign_id: campaign.id)
      handled("payment_campaign_chosen")

      # The approved account, given to the person who needs it — this is the
      # brief's payment-confusion mitigation arriving where it matters.
      <<~TEXT.strip
        #{campaign.name}. Pay only to:
        #{campaign.receiving_account_name}
        #{campaign.receiving_account_detail}

        How much will you give? Reply with an amount in #{campaign.currency},
        or describe what you will give if it is materials or labour.
      TEXT
    end

    def record_pledge
      campaign = MobilisationCampaign.find_by(id: conversation.context["campaign_id"])
      return restart_after_lost_context if campaign.blank?

      amount = text[/[\d.]+/]&.to_f
      contribution = household.contributions.build(
        mobilisation_campaign: campaign,
        change_reason: "Pledged over WhatsApp",
        audit_source_channel: "whatsapp"
      )

      if amount&.positive?
        contribution.assign_attributes(contribution_kind: :money, amount: amount)
      else
        contribution.assign_attributes(contribution_kind: :materials, item_description: text)
      end

      conversation.reset!

      unless contribution.save
        handled("payment_failed", contribution.errors.full_messages.to_sentence)
        return "That could not be recorded: #{contribution.errors.full_messages.to_sentence}. " \
               "Reply MENU to try again."
      end

      handled("pledge_recorded", contribution.reference)
      "Thank you. We have recorded #{contribution.describes}. Please pay to the " \
      "account above and keep your reference — the village office will confirm it."
    end

    # --- reads -------------------------------------------------------------
    # Reading household data over WhatsApp was a deliberate choice. A phone
    # number is weak proof of identity, so these are gated on communication
    # consent and every one is recorded as a disclosure.

    def show_applications
      return refuse_read unless may_read?

      cases = household.programme_cases.order(opened_on: :desc).limit(5)
      handled("read_applications")
      disclose!

      return "You have not asked for any support yet." if cases.empty?

      cases.map { |c| "#{c.programme_type.humanize}: #{c.status.humanize.downcase}" }
           .join("\n")
    end

    def show_receipts
      return refuse_read unless may_read?

      contributions = household.contributions.order(created_at: :desc).limit(5)
      handled("read_receipts")
      disclose!

      return "You have not given to any collection yet." if contributions.empty?

      contributions.map do |c|
        confirmed = c.reconciled? ? "confirmed" : c.status.humanize.downcase
        "#{c.describes} — #{confirmed}"
      end.join("\n")
    end

    def show_office
      handled("read_office")
      <<~TEXT.strip
        Nyika Village Office, open weekday mornings.

        For anything this service cannot do — adding or removing a member,
        changing what you have agreed to, or a question about a request — please
        speak to the office in person.
      TEXT
    end

    # --- plumbing ----------------------------------------------------------

    def continue_flow
      case conversation.state
      when "registering_name"             then continue_registration_name
      when "registering_location"         then finish_registration
      when "updating_contact"             then apply_update
      when "support_choosing_programme"   then choose_programme
      when "support_choosing_member"      then choose_member
      when "support_confirming_consent"   then confirm_support_consent
      when "paying_choosing_campaign"     then choose_campaign
      when "paying_amount"                then record_pledge
      else restart_after_lost_context
      end
    end

    def handle_stop
      conversation.reset!
      handled("stopped")
      "Ended. Reply MENU at any time to start again."
    end

    def handle_menu_request
      conversation.reset!
      handled("menu")
      household ? MENU : start_registration
    end

    def handle_lapsed_session
      handled("session_lapsed")
      return start_registration unless household

      "It has been a while, so we did not want to guess what that meant.\n\n#{MENU}"
    end

    def restart_after_lost_context
      conversation.reset!
      handled("context_lost")
      "Sorry — let us start again.\n\n#{household ? MENU : ''}".strip
    end

    def may_read?
      household.active_people.any? { |person| person.consented_to?(:communication) }
    end

    def refuse_read
      handled("read_refused_no_consent")
      "We cannot send your household's details by message because nobody in the " \
      "household has agreed to be contacted this way. Please speak to the village office."
    end

    def disclose!
      @disclosure = true
    end

    def record(body)
      OutboundMessage.create!(
        channel: @inbound.channel,
        to_number: conversation.contact_number,
        body: body,
        template_key: @inbound.handled_as,
        conversation: conversation,
        household: household,
        disclosure: @disclosure.present?
      )
    end

    def handled(action, note = nil)
      @inbound.update!(handled_as: action, handling_note: note)
    end

    def open_case_for(programme_type, beneficiary)
      household.programme_cases
               .where(programme_type: programme_type, beneficiary: beneficiary)
               .where.not(status: :closed)
               .first
    end

    def record_programme_consent(beneficiary)
      people = beneficiary ? [ beneficiary ] : household.active_people
      people.each do |person|
        next if person.consented_to?(:programme)

        person.consent_records.create!(
          purpose: :programme,
          consent_version: ConsentRecord::CURRENT_VERSION,
          channel: :whatsapp,
          granted_on: Date.current,
          change_reason: "Agreed over WhatsApp (message #{@inbound.id})",
          audit_source_channel: "whatsapp"
        )
      end
    end
  end
end
