# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_03_180000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "alert_subscriptions", force: :cascade do |t|
    t.integer "alert_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["alert_id"], name: "index_alert_subscriptions_on_alert_id"
    t.index ["user_id", "alert_id"], name: "index_alert_subscriptions_on_user_id_and_alert_id", unique: true
  end

  create_table "alerts", force: :cascade do |t|
    t.string "assessed_severity"
    t.integer "assigned_to_id"
    t.integer "author_id", null: false
    t.integer "category_id"
    t.string "category_other_description"
    t.string "client_request_digest"
    t.string "client_request_id"
    t.datetime "closed_at"
    t.text "closure_notes"
    t.string "closure_reason"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duplicate_of_id"
    t.string "kind", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "location_accuracy_meters", precision: 10, scale: 2
    t.datetime "location_captured_at"
    t.string "location_description"
    t.integer "location_id"
    t.string "location_source", null: false
    t.string "location_unavailable_reason"
    t.integer "lock_version", default: 0, null: false
    t.decimal "longitude", precision: 10, scale: 7
    t.json "photo_order", default: [], null: false
    t.string "priority"
    t.string "protocol", null: false
    t.boolean "publication_blocked", default: false, null: false
    t.string "reported_severity"
    t.string "requested_visibility", null: false
    t.datetime "resolved_at"
    t.string "status", default: "received", null: false
    t.datetime "status_changed_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "visibility", null: false
    t.index ["assigned_to_id"], name: "index_alerts_on_assigned_to_id"
    t.index ["author_id", "client_request_id"], name: "index_alerts_on_author_and_client_request", unique: true, where: "client_request_id IS NOT NULL"
    t.index ["author_id", "created_at"], name: "index_alerts_on_author_id_and_created_at"
    t.index ["category_id"], name: "index_alerts_on_category_id"
    t.index ["duplicate_of_id"], name: "index_alerts_on_duplicate_of_id"
    t.index ["kind", "visibility", "status"], name: "index_alerts_on_kind_and_visibility_and_status"
    t.index ["location_id"], name: "index_alerts_on_location_id"
    t.index ["protocol"], name: "index_alerts_on_protocol", unique: true
    t.index ["status", "created_at"], name: "index_alerts_on_status_and_created_at"
    t.check_constraint "(closed_at IS NULL AND closure_reason IS NULL) OR status = 'closed'", name: "alerts_closure_only_when_closed"
    t.check_constraint "(latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL)", name: "alerts_coordinates_pair"
    t.check_constraint "assessed_severity IS NULL OR assessed_severity IN ('low', 'moderate', 'high', 'critical')", name: "alerts_assessed_severity"
    t.check_constraint "category_other_description IS NULL OR length(category_other_description) <= 500", name: "alerts_category_other_description_length"
    t.check_constraint "client_request_id IS NULL OR (length(client_request_id) BETWEEN 8 AND 64 AND client_request_digest IS NOT NULL)", name: "alerts_client_request"
    t.check_constraint "closure_reason IS NULL OR closure_reason <> 'duplicate' OR duplicate_of_id IS NOT NULL", name: "alerts_duplicate_target_required"
    t.check_constraint "closure_reason IS NULL OR closure_reason IN ('resolved', 'duplicate', 'invalid', 'out_of_scope', 'other')", name: "alerts_closure_reason"
    t.check_constraint "description IS NULL OR length(description) <= 5000", name: "alerts_description_length"
    t.check_constraint "duplicate_of_id IS NULL OR (closure_reason = 'duplicate' AND duplicate_of_id <> id)", name: "alerts_duplicate_reference"
    t.check_constraint "kind <> 'occurrence' OR (title IS NOT NULL AND length(trim(title)) >= 5 AND description IS NOT NULL AND length(trim(description)) >= 10 AND category_id IS NOT NULL AND location_source <> 'unavailable')", name: "alerts_occurrence_required_fields"
    t.check_constraint "kind <> 'panic' OR (requested_visibility = 'restricted' AND visibility = 'restricted' AND client_request_id IS NOT NULL)", name: "alerts_panic_restricted"
    t.check_constraint "kind IN ('occurrence', 'panic')", name: "alerts_kind"
    t.check_constraint "latitude IS NULL OR (latitude >= -90 AND latitude <= 90)", name: "alerts_latitude_range"
    t.check_constraint "location_accuracy_meters IS NULL OR (location_accuracy_meters >= 0 AND location_source = 'gps')", name: "alerts_location_accuracy"
    t.check_constraint "location_captured_at IS NULL OR location_source = 'gps'", name: "alerts_location_captured_at"
    t.check_constraint "location_source <> 'manual' OR (latitude IS NULL AND (location_id IS NOT NULL OR (location_description IS NOT NULL AND length(trim(location_description)) BETWEEN 3 AND 160)))", name: "alerts_manual_location"
    t.check_constraint "location_source <> 'unavailable' OR (location_id IS NULL AND latitude IS NULL)", name: "alerts_unavailable_location"
    t.check_constraint "location_source IN ('gps', 'map', 'manual', 'unavailable')", name: "alerts_location_source"
    t.check_constraint "location_source NOT IN ('gps', 'map') OR latitude IS NOT NULL", name: "alerts_gps_coordinates"
    t.check_constraint "location_unavailable_reason IS NULL OR location_source = 'unavailable'", name: "alerts_location_unavailable_reason_source"
    t.check_constraint "location_unavailable_reason IS NULL OR location_unavailable_reason IN ('permission_denied', 'position_unavailable', 'timeout', 'not_supported', 'not_shared')", name: "alerts_location_unavailable_reason"
    t.check_constraint "lock_version >= 0", name: "alerts_lock_version"
    t.check_constraint "longitude IS NULL OR (longitude >= -180 AND longitude <= 180)", name: "alerts_longitude_range"
    t.check_constraint "priority IS NULL OR priority IN ('low', 'normal', 'high', 'urgent')", name: "alerts_priority"
    t.check_constraint "publication_blocked IN (0, 1)", name: "alerts_publication_blocked_boolean"
    t.check_constraint "reported_severity IS NULL OR reported_severity IN ('low', 'moderate', 'high', 'critical')", name: "alerts_reported_severity"
    t.check_constraint "requested_visibility IN ('internal', 'restricted', 'public_external')", name: "alerts_requested_visibility"
    t.check_constraint "resolved_at IS NULL OR status IN ('resolved', 'closed')", name: "alerts_resolved_at_status"
    t.check_constraint "status <> 'closed' OR (closed_at IS NOT NULL AND closure_reason IS NOT NULL)", name: "alerts_closed_fields"
    t.check_constraint "status <> 'resolved' OR resolved_at IS NOT NULL", name: "alerts_resolved_at"
    t.check_constraint "status IN ('received', 'triaging', 'in_progress', 'awaiting_information', 'resolved', 'closed')", name: "alerts_status"
    t.check_constraint "title IS NULL OR length(title) <= 160", name: "alerts_title_length"
    t.check_constraint "visibility = 'restricted' OR requested_visibility = 'internal'", name: "alerts_visibility_matches_request"
    t.check_constraint "visibility IN ('internal', 'restricted')", name: "alerts_visibility"
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.integer "actor_id"
    t.json "changeset", default: {}, null: false
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.text "reason"
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.index ["action", "created_at"], name: "index_audit_events_on_action_and_created_at"
    t.index ["actor_id", "created_at"], name: "index_audit_events_on_actor_id_and_created_at"
    t.index ["subject_type", "subject_id", "created_at"], name: "index_audit_events_on_subject_and_created_at"
    t.check_constraint "actor_id IS NOT NULL OR action LIKE 'system.%'", name: "audit_events_actor_required"
    t.check_constraint "length(action) BETWEEN 3 AND 80", name: "audit_events_action_length"
    t.check_constraint "reason IS NULL OR length(reason) <= 1000", name: "audit_events_reason_length"
  end

  create_table "categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "requires_details", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_categories_on_active_and_position"
    t.index ["code"], name: "index_categories_on_code", unique: true
    t.check_constraint "length(code) BETWEEN 2 AND 40 AND code = lower(code)", name: "categories_code_format"
    t.check_constraint "length(name) BETWEEN 1 AND 80", name: "categories_name_length"
  end

  create_table "comment_likes", force: :cascade do |t|
    t.integer "comment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["comment_id"], name: "index_comment_likes_on_comment_id"
    t.index ["user_id", "comment_id"], name: "index_comment_likes_on_user_id_and_comment_id", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.integer "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "edited_at"
    t.integer "lock_version", default: 0, null: false
    t.integer "parent_id"
    t.integer "publication_id", null: false
    t.text "removal_reason"
    t.datetime "removed_at"
    t.integer "removed_by_id"
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_comments_on_author_id"
    t.index ["parent_id", "created_at"], name: "index_comments_on_parent_id_and_created_at"
    t.index ["publication_id", "created_at"], name: "index_comments_on_publication_id_and_created_at"
    t.index ["removed_by_id"], name: "index_comments_on_removed_by_id"
    t.check_constraint "length(trim(body)) BETWEEN 1 AND 2000", name: "comments_body_length"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "comments_parent_not_self"
    t.check_constraint "removed_at IS NULL OR (removed_by_id IS NOT NULL AND removal_reason IS NOT NULL AND length(trim(removal_reason)) > 0)", name: "comments_removal_fields"
  end

  create_table "content_reports", force: :cascade do |t|
    t.integer "comment_id"
    t.datetime "created_at", null: false
    t.text "details"
    t.integer "publication_id"
    t.string "reason", null: false
    t.integer "reporter_id", null: false
    t.text "resolution_notes"
    t.datetime "reviewed_at"
    t.integer "reviewed_by_id"
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id"], name: "index_content_reports_on_comment_id"
    t.index ["publication_id"], name: "index_content_reports_on_publication_id"
    t.index ["reporter_id", "comment_id"], name: "index_content_reports_unique_comment_target", unique: true, where: "comment_id IS NOT NULL"
    t.index ["reporter_id", "publication_id"], name: "index_content_reports_unique_publication_target", unique: true, where: "publication_id IS NOT NULL"
    t.index ["reviewed_by_id"], name: "index_content_reports_on_reviewed_by_id"
    t.index ["state", "created_at"], name: "index_content_reports_on_state_and_created_at"
    t.check_constraint "(publication_id IS NOT NULL AND comment_id IS NULL) OR (publication_id IS NULL AND comment_id IS NOT NULL)", name: "content_reports_single_target"
    t.check_constraint "details IS NULL OR length(details) <= 2000", name: "content_reports_details_length"
    t.check_constraint "reason <> 'other' OR (details IS NOT NULL AND length(trim(details)) > 0)", name: "content_reports_other_details"
    t.check_constraint "reason IN ('spam', 'harassment', 'misinformation', 'privacy', 'inappropriate', 'other')", name: "content_reports_reason"
    t.check_constraint "state = 'pending' OR (reviewed_by_id IS NOT NULL AND reviewed_at IS NOT NULL)", name: "content_reports_review_fields"
    t.check_constraint "state IN ('pending', 'actioned', 'dismissed')", name: "content_reports_state"
  end

  create_table "locations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.decimal "reference_latitude", precision: 10, scale: 7
    t.decimal "reference_longitude", precision: 10, scale: 7
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_locations_on_active_and_position"
    t.index ["code"], name: "index_locations_on_code", unique: true
    t.check_constraint "(reference_latitude IS NULL AND reference_longitude IS NULL) OR (reference_latitude IS NOT NULL AND reference_longitude IS NOT NULL)", name: "locations_reference_pair"
    t.check_constraint "length(code) BETWEEN 2 AND 40 AND code = lower(code)", name: "locations_code_format"
    t.check_constraint "length(name) BETWEEN 1 AND 120", name: "locations_name_length"
    t.check_constraint "reference_latitude IS NULL OR (reference_latitude >= -90 AND reference_latitude <= 90)", name: "locations_reference_latitude_range"
    t.check_constraint "reference_longitude IS NULL OR (reference_longitude >= -180 AND reference_longitude <= 180)", name: "locations_reference_longitude_range"
  end

  create_table "presentation_profiles", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.string "delivery", null: false
    t.text "description"
    t.string "name", null: false
    t.json "selections", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_presentation_profiles_on_single_active", unique: true, where: "active"
    t.index ["name"], name: "index_presentation_profiles_on_name", unique: true
  end

  create_table "publication_bookmarks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "publication_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["publication_id"], name: "index_publication_bookmarks_on_publication_id"
    t.index ["user_id", "publication_id"], name: "index_publication_bookmarks_on_user_id_and_publication_id", unique: true
  end

  create_table "publication_likes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "publication_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["publication_id"], name: "index_publication_likes_on_publication_id"
    t.index ["user_id", "publication_id"], name: "index_publication_likes_on_user_id_and_publication_id", unique: true
  end

  create_table "publication_subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "publication_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["publication_id"], name: "index_publication_subscriptions_on_publication_id"
    t.index ["user_id", "publication_id"], name: "index_publication_subscriptions_on_user_id_and_publication_id", unique: true
  end

  create_table "publications", force: :cascade do |t|
    t.integer "alert_id"
    t.string "approval_method"
    t.integer "author_id", null: false
    t.text "body"
    t.boolean "comments_enabled", default: true, null: false
    t.integer "content_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "kind", null: false
    t.integer "lock_version", default: 0, null: false
    t.boolean "moderation_blocked", default: false, null: false
    t.datetime "published_at"
    t.text "review_reason"
    t.string "review_status", default: "not_submitted", null: false
    t.datetime "reviewed_at"
    t.integer "reviewed_by_id"
    t.integer "reviewed_content_version"
    t.datetime "source_changed_at"
    t.string "state", default: "draft", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "visibility", null: false
    t.datetime "withdrawn_at"
    t.index ["alert_id"], name: "index_publications_on_alert_id", unique: true
    t.index ["author_id"], name: "index_publications_on_author_id"
    t.index ["reviewed_by_id"], name: "index_publications_on_reviewed_by_id"
    t.index ["state", "visibility", "published_at"], name: "index_publications_on_state_and_visibility_and_published_at"
    t.check_constraint "(kind = 'occurrence' AND alert_id IS NOT NULL) OR (kind <> 'occurrence' AND alert_id IS NULL)", name: "publications_alert_source"
    t.check_constraint "(kind = 'occurrence' AND title IS NULL AND body IS NULL) OR (kind <> 'occurrence' AND title IS NOT NULL AND length(trim(title)) BETWEEN 5 AND 160 AND body IS NOT NULL AND length(trim(body)) BETWEEN 10 AND 10000)", name: "publications_canonical_content"
    t.check_constraint "approval_method IS NULL OR approval_method IN ('administrator', 'verified_author')", name: "publications_approval_method"
    t.check_constraint "content_version >= 1 AND lock_version >= 0", name: "publications_versions"
    t.check_constraint "expires_at IS NULL OR published_at IS NULL OR expires_at > published_at", name: "publications_expires_after_publication"
    t.check_constraint "kind <> 'notice' OR state <> 'published' OR expires_at IS NOT NULL", name: "publications_notice_expires"
    t.check_constraint "kind IN ('occurrence', 'notice', 'news')", name: "publications_kind"
    t.check_constraint "review_status <> 'rejected' OR (review_reason IS NOT NULL AND length(trim(review_reason)) > 0)", name: "publications_rejection_reason"
    t.check_constraint "review_status IN ('not_submitted', 'pending', 'approved', 'rejected')", name: "publications_review_status"
    t.check_constraint "review_status NOT IN ('approved', 'rejected') OR (reviewed_at IS NOT NULL AND reviewed_content_version IS NOT NULL AND (reviewed_by_id IS NOT NULL OR (review_status = 'approved' AND approval_method = 'verified_author')))", name: "publications_review_fields"
    t.check_constraint "state <> 'published' OR (published_at IS NOT NULL AND ((kind = 'occurrence' AND visibility = 'internal') OR (review_status = 'approved' AND reviewed_content_version = content_version)))", name: "publications_published_requires_approval"
    t.check_constraint "state <> 'withdrawn' OR withdrawn_at IS NOT NULL", name: "publications_withdrawn_at"
    t.check_constraint "state IN ('draft', 'published', 'withdrawn')", name: "publications_state"
    t.check_constraint "visibility IN ('internal', 'public_external')", name: "publications_visibility"
  end

  create_table "roles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_roles_on_code", unique: true
    t.check_constraint "length(code) BETWEEN 2 AND 40 AND code = lower(code)", name: "roles_code_format"
    t.check_constraint "length(name) BETWEEN 1 AND 80", name: "roles_name_length"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "user_follows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "followed_id", null: false
    t.integer "follower_id", null: false
    t.datetime "updated_at", null: false
    t.index ["followed_id"], name: "index_user_follows_on_followed_id"
    t.index ["follower_id", "followed_id"], name: "index_user_follows_on_follower_id_and_followed_id", unique: true
    t.check_constraint "follower_id <> followed_id", name: "user_follows_not_self"
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "granted_by_id"
    t.integer "role_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["granted_by_id"], name: "index_user_roles_on_granted_by_id"
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.text "bio"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "display_name"
    t.string "email_address", null: false
    t.datetime "email_verified_at"
    t.string "password_digest", null: false
    t.boolean "public_profile", default: false, null: false
    t.text "registration_review_reason"
    t.datetime "registration_reviewed_at"
    t.integer "registration_reviewed_by_id"
    t.string "registration_role_code"
    t.string "registration_status", default: "approved", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.datetime "verified_at"
    t.integer "verified_by_id"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["registration_reviewed_by_id"], name: "index_users_on_registration_reviewed_by_id"
    t.index ["registration_status", "created_at"], name: "index_users_on_registration_status_and_created_at"
    t.index ["username"], name: "index_users_on_username", unique: true
    t.index ["verified_by_id"], name: "index_users_on_verified_by_id"
    t.check_constraint "(verified_at IS NULL AND verified_by_id IS NULL) OR (verified_at IS NOT NULL AND verified_by_id IS NOT NULL)", name: "users_verification_pair"
    t.check_constraint "bio IS NULL OR length(bio) <= 500", name: "users_bio_length"
    t.check_constraint "display_name IS NULL OR length(display_name) BETWEEN 1 AND 80", name: "users_display_name_length"
    t.check_constraint "registration_role_code IS NULL OR registration_role_code IN ('visitor', 'professor', 'student')", name: "users_registration_role_valid"
    t.check_constraint "registration_status IN ('pending', 'approved', 'rejected')", name: "users_registration_status_valid"
    t.check_constraint "username IS NULL OR (length(username) BETWEEN 3 AND 30 AND username = lower(username))", name: "users_username_length_and_case"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "alert_subscriptions", "alerts"
  add_foreign_key "alert_subscriptions", "users"
  add_foreign_key "alerts", "alerts", column: "duplicate_of_id"
  add_foreign_key "alerts", "categories"
  add_foreign_key "alerts", "locations"
  add_foreign_key "alerts", "users", column: "assigned_to_id"
  add_foreign_key "alerts", "users", column: "author_id"
  add_foreign_key "audit_events", "users", column: "actor_id"
  add_foreign_key "comment_likes", "comments"
  add_foreign_key "comment_likes", "users"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "publications"
  add_foreign_key "comments", "users", column: "author_id"
  add_foreign_key "comments", "users", column: "removed_by_id"
  add_foreign_key "content_reports", "comments"
  add_foreign_key "content_reports", "publications"
  add_foreign_key "content_reports", "users", column: "reporter_id"
  add_foreign_key "content_reports", "users", column: "reviewed_by_id"
  add_foreign_key "publication_bookmarks", "publications"
  add_foreign_key "publication_bookmarks", "users"
  add_foreign_key "publication_likes", "publications"
  add_foreign_key "publication_likes", "users"
  add_foreign_key "publication_subscriptions", "publications"
  add_foreign_key "publication_subscriptions", "users"
  add_foreign_key "publications", "alerts"
  add_foreign_key "publications", "users", column: "author_id"
  add_foreign_key "publications", "users", column: "reviewed_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "user_follows", "users", column: "followed_id"
  add_foreign_key "user_follows", "users", column: "follower_id"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "user_roles", "users", column: "granted_by_id"
  add_foreign_key "users", "users", column: "registration_reviewed_by_id"
  add_foreign_key "users", "users", column: "verified_by_id"
end
