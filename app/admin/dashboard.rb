ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    panel "Capture queue — drafts awaiting completion" do
      if Household.capture_queue.any?
        table_for Household.capture_queue.limit(10) do
          column("Reference") { |h| link_to h.reference, admin_household_path(h) }
          column(:name)
          column("Missing") do |h|
            missing = h.missing_required_fields
            missing.any? ? status_tag(missing.map(&:humanize).join(", "), class: :error) : status_tag("Complete", class: :ok)
          end
          column("Members") { |h| h.active_people.count }
        end
      else
        para "Nothing waiting to be captured."
      end
    end

    panel "Verification queue — awaiting a second pair of eyes" do
      if Household.verification_queue.any?
        table_for Household.verification_queue.limit(10) do
          column("Reference") { |h| link_to h.reference, admin_household_path(h) }
          column(:name)
          column("Submitted") { |h| h.updated_at.strftime("%d %b %Y") }
          column("Members") { |h| h.active_people.count }
        end
      else
        para "Nothing waiting to be verified."
      end
    end

    # Only rendered for roles allowed to see casework — a registrar must not
    # learn from the dashboard that a family sought welfare support.
    if authorized?(:read, ProgrammeCase)
      panel "Programme cases needing attention" do
        cases = ProgrammeCase.awaiting_action.order(:opened_on)

        if cases.any?
          table_for cases.limit(10) do
            column("Case") { |c| link_to c.reference, admin_programme_case_path(c) }
            column("Household") { |c| c.household.reference }
            column("Programme") { |c| c.programme_type.humanize }
            column("Waiting on") { |c| c.blockers.first || "nothing" }
          end
        else
          para "No cases waiting on consent or evidence."
        end
      end

      panel "Cases ready to submit" do
        ready = ProgrammeCase.submission_queue

        if ready.any?
          table_for ready do
            column("Case") { |c| link_to c.reference, admin_programme_case_path(c) }
            column("Household") { |c| c.household.reference }
            column("Programme") { |c| c.programme_type.humanize }
            column("Opened") { |c| c.opened_on }
          end
        else
          para "Nothing ready to go to the programme office."
        end
      end
    end

    # Hidden from a programme manager: the other half of the political firewall.
    if authorized?(:read, Contribution)
      panel "Open campaigns" do
        campaigns = MobilisationCampaign.live.order(:opens_on)

        if campaigns.any?
          table_for campaigns do
            column("Campaign") { |c| link_to c.reference, admin_mobilisation_campaign_path(c) }
            column(:name)
            column("Target") { |c| c.target_amount ? "#{c.currency} #{c.target_amount}" : c.target_description }
            column("Received") { |c| "#{c.currency} #{c.received_amount}" }
            column("Progress") { |c| c.progress_percentage ? "#{c.progress_percentage}%" : "—" }
            column("Closes") { |c| c.closes_on }
          end
        else
          para "No campaigns are open."
        end
      end

      panel "Payments needing attention" do
        exceptions = Contribution.needs_attention
        unverified_cash = Receipt.where(payment_rail: :cash_collector, verification_status: :recorded)

        table_for [
          { issue: "Contributions in exception", count: exceptions.count },
          { issue: "Cash receipts awaiting verification", count: unverified_cash.count },
          { issue: "Contributions pledged but not reconciled", count: Contribution.outstanding.count }
        ] do
          column("Issue") { |r| r[:issue] }
          column("Count") { |r| r[:count].zero? ? status_tag("0", class: :ok) : status_tag(r[:count].to_s, class: :error) }
        end
      end
    end

    panel "Registry at a glance" do
      table_for Household.statuses.keys do
        column("Status") { |s| status_tag s.humanize }
        column("Households") { |s| Household.where(status: s).count }
      end
    end

    panel "Consent by purpose" do
      # Shown per purpose precisely because there is no single consent figure:
      # agreeing to be contacted is not agreeing to be enrolled or paid.
      table_for ConsentRecord.purposes.keys do
        column("Purpose") { |p| p.humanize }
        column("Active") { |p| ConsentRecord.active.for_purpose(p).count }
        column("Withdrawn") { |p| ConsentRecord.withdrawn.for_purpose(p).count }
      end
    end

    panel "Exceptions — needing attention" do
      rows = [
        { issue: "Households missing required fields",
          count: Household.live.count { |h| h.missing_required_fields.any? } },
        { issue: "Households with no members recorded",
          count: Household.live.count { |h| h.active_people.none? } },
        { issue: "People with no consent recorded",
          count: Person.active.count { |p| p.consent_records.active.none? } }
      ]
      table_for rows do
        column("Issue") { |r| r[:issue] }
        column("Count") { |r| r[:count].zero? ? status_tag("0", class: :ok) : status_tag(r[:count].to_s, class: :error) }
      end
    end

    panel "Recent activity — the audit trail" do
      table_for PaperTrail::Version.order(created_at: :desc).limit(12) do
        column("When") { |v| v.created_at.strftime("%d %b %H:%M") }
        column("Who") { |v| audit_actor_label(v) }
        column("Record") { |v| "#{v.item_type} ##{v.item_id}" }
        column("What") { |v| v.event.humanize }
        column("Reason") { |v| v.reason.presence || "—" }
        column("Channel") { |v| audit_channel_label(v) }
      end
    end
  end
end
