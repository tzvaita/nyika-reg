# Turns however someone wrote a phone number into one canonical form, so an
# inbound WhatsApp message can be matched to a household.
#
# The same number reaches us as "0771234567", "077 123 4567", "+263 77 123 4567"
# and "263771234567". Without one stored form, matching is a guessing game.
#
# This adds no new kind of personal data: a contact method is already recorded
# (the brief lists "contact method where available"). It only makes what is
# already held matchable.
#
# No gem for this deliberately — it is string handling, and a dependency that
# ships the world's numbering plans is more than a POC for one village needs.
class PhoneNumber
  # Zimbabwe. Configurable because the same code should work if this is ever run
  # for a village elsewhere.
  DEFAULT_COUNTRY_CODE = ENV.fetch("DEFAULT_COUNTRY_CODE", "263").freeze

  # Mobile prefixes in use locally: Econet 77/78, NetOne 71, Telecel 73.
  # Used only to spot a national number written without its leading zero.
  NATIONAL_MOBILE_PREFIXES = %w[71 73 77 78].freeze

  attr_reader :raw

  def initialize(raw, country_code: DEFAULT_COUNTRY_CODE)
    @raw = raw.to_s
    @country_code = country_code.to_s
  end

  def self.normalise(raw, **options)
    new(raw, **options).e164
  end

  # The canonical form, or nil if this cannot plausibly be a phone number.
  # Returning nil rather than raising: a registrar typing "ask at the shop" into
  # a contact field is doing something reasonable, not causing an error.
  def e164
    return nil if digits.blank?

    candidate =
      if raw.strip.start_with?("+")
        digits
      elsif digits.start_with?("00")
        digits[2..]
      elsif digits.start_with?("0")
        without_trunk = digits[1..]
        # "0263771234567" — a trunk zero in front of a full international number.
        # Prepending the country code again would produce a plausible-looking but
        # entirely wrong number, which is worse than rejecting it.
        without_trunk.start_with?(@country_code) ? without_trunk : "#{@country_code}#{without_trunk}"
      elsif digits.start_with?(@country_code)
        digits
      elsif national_mobile_without_zero?
        "#{@country_code}#{digits}"
      else
        digits
      end

    plausible?(candidate) ? "+#{candidate}" : nil
  end

  def valid?
    e164.present?
  end

  def to_s
    e164 || raw
  end

  def ==(other)
    other.is_a?(PhoneNumber) && e164 == other.e164
  end

  private

  def digits
    @digits ||= raw.gsub(/[^0-9]/, "")
  end

  # "771234567" — a local mobile number with the trunk zero dropped, which is how
  # people often say and write them.
  def national_mobile_without_zero?
    digits.length == 9 && NATIONAL_MOBILE_PREFIXES.include?(digits[0, 2])
  end

  # Deliberately loose. Numbering plans vary and an over-strict check would
  # silently discard real numbers; the cost of accepting an odd one is only that
  # a message fails to send and shows in the outbox as failed.
  def plausible?(candidate)
    candidate.length.between?(8, 15)
  end
end
