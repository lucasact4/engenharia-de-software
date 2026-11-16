class CreateAnonymousSubmissionAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :anonymous_submission_audits do |t|
      t.references :alert, null: false, foreign_key: true, index: { unique: true }
      t.text :ip_address_ciphertext, null: false
      t.text :user_agent_ciphertext, null: false
      t.datetime :submitted_at, null: false
      t.timestamps
    end
  end
end
