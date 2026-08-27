module VillageHelper
  # The registry's public contact number, in the two forms the site needs.
  # Kept in one place so a change does not have to be chased across pages.
  REGISTRY_NUMBER_E164 = "263775103375".freeze
  REGISTRY_NUMBER_DISPLAY = "+263 77 510 3375".freeze

  def registry_number
    REGISTRY_NUMBER_DISPLAY
  end

  def registry_whatsapp_url
    "https://wa.me/#{REGISTRY_NUMBER_E164}"
  end

  def registry_sms_url
    "sms:+#{REGISTRY_NUMBER_E164}"
  end

  def registry_tel_url
    "tel:+#{REGISTRY_NUMBER_E164}"
  end
end
