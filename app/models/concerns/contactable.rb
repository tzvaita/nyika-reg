# Keeps a normalised phone number in step with whatever was typed.
#
# Whoever is capturing writes the number however they know it; this stores one
# canonical form beside it so an inbound message can be matched. If what they
# wrote is not a number at all — "ask at the shop" — the free text is kept and
# the normalised column stays empty, which is the correct outcome rather than an
# error.
module Contactable
  extend ActiveSupport::Concern

  class_methods do
    # Which free-text field feeds the normalised one.
    def contact_source_attribute(name = nil)
      @contact_source_attribute = name if name
      @contact_source_attribute
    end

    # Finds a record by however the number is written.
    def find_by_contact_number(raw)
      number = PhoneNumber.normalise(raw)
      return nil if number.blank?

      find_by(contact_number: number)
    end

    def with_contact_number
      where.not(contact_number: [ nil, "" ])
    end
  end

  included do
    before_validation :normalise_contact_number
  end

  def reachable_by_message?
    contact_number.present?
  end

  private

  def normalise_contact_number
    source = self.class.contact_source_attribute
    return if source.blank?

    # An explicitly set contact_number wins; otherwise derive it from the text.
    if will_save_change_to_attribute?(:contact_number) && contact_number.present?
      self.contact_number = PhoneNumber.normalise(contact_number)
    elsif will_save_change_to_attribute?(source) || contact_number.blank?
      self.contact_number = PhoneNumber.normalise(public_send(source))
    end
  end
end
