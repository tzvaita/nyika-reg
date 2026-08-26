class CreateMobilisationCampaigns < ActiveRecord::Migration[8.1]
  # The brief's "Mobilisation campaign": campaign ID, purpose, target, opening
  # date, closing date, and approved receiving account or collector.
  #
  # THE PLATFORM DOES NOT HOLD FUNDS. Money moves through licensed rails
  # (EcoCash, InnBucks, a bank) or to an authorised cash collector. What this
  # table records is where money is supposed to go, so a resident can be told
  # the right account and a payment can be matched afterwards. The registry
  # orchestrates and reconciles; it is not a bank.
  def change
    create_table :mobilisation_campaigns do |t|
      t.string  :reference, null: false
      t.string  :name, null: false
      t.text    :purpose

      t.integer :campaign_type, null: false, default: 0
      t.integer :status, null: false, default: 0

      # Whether contributing is voluntary or an obligation the village has
      # formally approved. The deck asks for this explicitly — being asked and
      # being required are different things and residents must be told which.
      t.integer :obligation, null: false, default: 0

      # A campaign may target money, or materials, or labour.
      t.decimal :target_amount, precision: 12, scale: 2
      t.string  :currency, null: false, default: "USD"
      t.string  :target_description
      t.decimal :suggested_contribution, precision: 12, scale: 2

      t.date    :opens_on, null: false
      t.date    :closes_on

      # The approved receiving account or collector. This is the mitigation for
      # the brief's "payment confusion" risk: residents paying the wrong account.
      # A campaign cannot open without one.
      t.string  :receiving_account_name
      t.string  :receiving_account_detail
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime   :approved_at

      t.references :reporting_owner, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :mobilisation_campaigns, :reference, unique: true
    add_index :mobilisation_campaigns, :status
  end
end
