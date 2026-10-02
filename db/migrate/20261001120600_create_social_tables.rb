# Vínculos sociais de publicações; índices únicos impedem duplicações por retransmissão.
class CreateSocialTables < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :publication, null: false, foreign_key: true, index: false
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :parent, foreign_key: { to_table: :comments }, index: false
      t.text :body, null: false
      t.datetime :edited_at
      t.datetime :deleted_at
      t.datetime :removed_at
      t.references :removed_by, foreign_key: { to_table: :users }
      t.text :removal_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamps

      t.index %i[publication_id created_at]
      t.index %i[parent_id created_at]

      t.check_constraint "length(trim(body)) BETWEEN 1 AND 2000", name: "comments_body_length"
      t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "comments_parent_not_self"
      t.check_constraint "removed_at IS NULL OR (removed_by_id IS NOT NULL AND removal_reason IS NOT NULL " \
                         "AND length(trim(removal_reason)) > 0)",
                         name: "comments_removal_fields"
    end

    create_table :publication_likes do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :publication, null: false, foreign_key: true
      t.timestamps

      t.index %i[user_id publication_id], unique: true
    end

    create_table :comment_likes do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :comment, null: false, foreign_key: true
      t.timestamps

      t.index %i[user_id comment_id], unique: true
    end

    create_table :publication_bookmarks do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :publication, null: false, foreign_key: true
      t.timestamps

      t.index %i[user_id publication_id], unique: true
    end

    create_table :publication_subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :publication, null: false, foreign_key: true
      t.timestamps

      t.index %i[user_id publication_id], unique: true
    end

    create_table :alert_subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :alert, null: false, foreign_key: true
      t.timestamps

      t.index %i[user_id alert_id], unique: true
    end

    create_table :user_follows do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }, index: false
      t.references :followed, null: false, foreign_key: { to_table: :users }
      t.timestamps

      t.index %i[follower_id followed_id], unique: true
      t.check_constraint "follower_id <> followed_id", name: "user_follows_not_self"
    end

    create_table :content_reports do |t|
      t.references :reporter, null: false, foreign_key: { to_table: :users }, index: false
      t.references :publication, foreign_key: true
      t.references :comment, foreign_key: true
      t.string :reason, null: false
      t.text :details
      t.string :state, null: false, default: "pending"
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :resolution_notes
      t.timestamps

      t.index %i[reporter_id publication_id], unique: true, where: "publication_id IS NOT NULL",
              name: "index_content_reports_unique_publication_target"
      t.index %i[reporter_id comment_id], unique: true, where: "comment_id IS NOT NULL",
              name: "index_content_reports_unique_comment_target"
      t.index %i[state created_at]

      t.check_constraint "(publication_id IS NOT NULL AND comment_id IS NULL) OR " \
                         "(publication_id IS NULL AND comment_id IS NOT NULL)",
                         name: "content_reports_single_target"
      t.check_constraint "reason IN ('spam', 'harassment', 'misinformation', 'privacy', 'inappropriate', 'other')",
                         name: "content_reports_reason"
      t.check_constraint "reason <> 'other' OR (details IS NOT NULL AND length(trim(details)) > 0)",
                         name: "content_reports_other_details"
      t.check_constraint "details IS NULL OR length(details) <= 2000", name: "content_reports_details_length"
      t.check_constraint "state IN ('pending', 'actioned', 'dismissed')", name: "content_reports_state"
      t.check_constraint "state = 'pending' OR (reviewed_by_id IS NOT NULL AND reviewed_at IS NOT NULL)",
                         name: "content_reports_review_fields"
    end
  end
end
