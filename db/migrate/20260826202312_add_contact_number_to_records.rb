class AddContactNumberToRecords < ActiveRecord::Migration[8.1]
  # A normalised (E.164) phone number, so an inbound WhatsApp message can be
  # matched to a household.
  #
  # This sits ALONGSIDE the existing free-text contact fields rather than
  # replacing them. "Ask for Mai Ncube at the shop" and "the phone at the school"
  # are legitimate contact methods in a village and must not be lost just because
  # they cannot be dialled.
  def change
    add_column :people, :contact_number, :string
    add_column :households, :contact_number, :string
    add_column :registration_requests, :contact_number, :string

    # Matching an inbound number is a lookup on every message, so index them.
    add_index :people, :contact_number
    add_index :households, :contact_number
    add_index :registration_requests, :contact_number

    # Backfill from what is already recorded, where it parses as a number.
    up_only do
      say_with_time "normalising existing contact details" do
        [ [ Person, :contact_method ], [ Household, :principal_contact ],
          [ RegistrationRequest, :contact_method ] ].each do |model, source|
          model.reset_column_information
          model.where.not(source => [ nil, "" ]).find_each do |record|
            number = PhoneNumber.normalise(record.public_send(source))
            record.update_columns(contact_number: number) if number
          end
        end
      end
    end
  end
end
