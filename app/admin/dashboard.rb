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
