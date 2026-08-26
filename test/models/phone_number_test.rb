require "test_helper"

# Matching an inbound WhatsApp message to a household depends entirely on this,
# so the awkward inputs matter more than the tidy ones.
class PhoneNumberTest < ActiveSupport::TestCase
  test "the same number written any way normalises to one form" do
    written = [ "0771234567", "077 123 4567", "077-123-4567", "(077) 123 4567",
                "+263771234567", "+263 77 123 4567", "263771234567",
                "00263771234567", "771234567" ]

    normalised = written.map { |number| PhoneNumber.normalise(number) }.uniq

    assert_equal [ "+263771234567" ], normalised,
                 "these are all the same number and must match each other"
  end

  test "a number extracted from surrounding words" do
    # How a registrar actually types it.
    assert_equal "+263771234567", PhoneNumber.normalise("Sekuru Moyo 077 123 4567")
  end

  test "a trunk zero in front of an international number is not double-prefixed" do
    # "0263..." would otherwise become +263263..., a plausible-looking but
    # entirely wrong number — worse than rejecting it.
    assert_equal "+263771234567", PhoneNumber.normalise("0263771234567")
  end

  test "text that is not a number returns nothing rather than raising" do
    # "Ask at the shop" is a legitimate contact method in a village.
    [ "ask at the shop", "the phone at the school", "", "   ", nil, "12" ].each do |input|
      assert_nil PhoneNumber.normalise(input), "#{input.inspect} should not parse"
    end
  end

  test "an implausibly long string is rejected" do
    assert_nil PhoneNumber.normalise("07712345678901234567")
  end

  test "local mobile prefixes are recognised without the trunk zero" do
    { "771234567" => "+263771234567",   # Econet
      "712345678" => "+263712345678",   # NetOne
      "731234567" => "+263731234567",   # Telecel
      "781234567" => "+263781234567" }.each do |input, expected|
      assert_equal expected, PhoneNumber.normalise(input)
    end
  end

  test "two phone numbers are equal when they mean the same number" do
    assert_equal PhoneNumber.new("0771234567"), PhoneNumber.new("+263 77 123 4567")
  end

  test "the country code is configurable rather than hardcoded" do
    assert_equal "+27821234567", PhoneNumber.normalise("0821234567", country_code: "27")
  end
end
