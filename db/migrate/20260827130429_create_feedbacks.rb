class CreateFeedbacks < ActiveRecord::Migration[8.1]
  # "Have your say" — resident voice, not resident data.
  #
  # A name and contact are OPTIONAL on purpose: someone raising a complaint about
  # the village office should be able to do so without identifying themselves,
  # and a comment that can only be made under a name is not really free comment.
  def change
    create_table :feedbacks do |t|
      t.string  :name
      t.string  :contact_method
      t.integer :category, null: false, default: 0
      t.text    :message, null: false

      t.integer :status, null: false, default: 0
      t.text    :response
      t.references :handled_by, foreign_key: { to_table: :users }
      t.datetime :handled_at

      t.timestamps
    end

    add_index :feedbacks, :status
    add_index :feedbacks, :category
  end
end
