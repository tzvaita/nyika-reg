class CreateRegistrationRequests < ActiveRecord::Migration[8.1]
  # Someone asking to be registered. Deliberately NOT a household.
  #
  # A stranger on the internet must not be able to write into the register, so
  # this creates an inert request that a registrar has to action: they visit or
  # call, explain what registration means, take consent properly, and only then
  # capture a household.
  #
  # FIELD MINIMISATION applies harder here than anywhere else, because this is
  # personal data about someone who has consented to nothing yet. Enough to find
  # them and call them, and nothing else: no ages, no household composition, no
  # identity numbers. Requests are closed once actioned.
  def change
    create_table :registration_requests do |t|
      t.string  :name, null: false            # who to ask for
      t.string  :contact_method               # how to reach them
      t.string  :location_hint                # roughly where to find them, in words
      t.text    :note                         # anything they want the office to know

      t.integer :status, null: false, default: 0

      t.references :handled_by, foreign_key: { to_table: :users }
      t.datetime   :handled_at
      t.text       :outcome_note

      # Set once a registrar has captured them, linking the request to the record
      # it produced.
      t.references :household, foreign_key: true

      t.timestamps
    end

    add_index :registration_requests, :status
  end
end
