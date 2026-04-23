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

ActiveRecord::Schema[8.1].define(version: 2026_04_20_101139) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "postgis"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "disease_type", ["diphtheria", "human_papillomavirus", "influenza", "measles", "meningitis_a", "meningitis_c", "meningitis_w", "meningitis_y", "mumps", "polio", "rubella", "tetanus", "varicella"]
  create_enum "programme_type", ["flu", "hpv", "menacwy", "mmr", "td_ipv"]

  create_table "access_log_entries", force: :cascade do |t|
    t.integer "action", null: false
    t.integer "controller", null: false
    t.datetime "created_at", null: false
    t.bigint "patient_id", null: false
    t.jsonb "request_details"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["patient_id"], name: "index_access_log_entries_on_patient_id"
    t.index ["user_id"], name: "index_access_log_entries_on_user_id"
  end

  create_table "active_record_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.string "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_active_record_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_active_record_sessions_on_updated_at"
  end

  create_table "archive_reasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id"
    t.string "other_details", default: "", null: false
    t.bigint "patient_id", null: false
    t.bigint "team_id", null: false
    t.integer "type", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_archive_reasons_on_created_by_user_id"
    t.index ["patient_id", "team_id"], name: "index_archive_reasons_on_patient_id_and_team_id", unique: true
    t.index ["patient_id"], name: "index_archive_reasons_on_patient_id"
    t.index ["team_id", "patient_id"], name: "index_archive_reasons_on_team_id_and_patient_id", unique: true
    t.index ["team_id"], name: "index_archive_reasons_on_team_id"
  end

  create_table "attendance_records", force: :cascade do |t|
    t.boolean "attending", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.bigint "location_id", null: false
    t.bigint "patient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_attendance_records_on_location_id"
    t.index ["patient_id", "location_id", "date"], name: "idx_on_patient_id_location_id_date_e5912f40c4", unique: true
    t.index ["patient_id"], name: "index_attendance_records_on_patient_id"
  end

  create_table "audits", force: :cascade do |t|
    t.string "action"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "auditable_id"
    t.string "auditable_type"
    t.jsonb "audited_changes"
    t.string "comment"
    t.datetime "created_at"
    t.string "remote_address"
    t.string "request_uuid"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "batches", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.date "expiry"
    t.string "number", null: false
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.bigint "vaccine_id", null: false
    t.index ["team_id", "number", "expiry", "vaccine_id"], name: "index_batches_on_team_id_and_number_and_expiry_and_vaccine_id", unique: true
    t.index ["vaccine_id"], name: "index_batches_on_vaccine_id"
  end

  create_table "careplus_report_vaccination_records", primary_key: ["careplus_report_id", "vaccination_record_id"], force: :cascade do |t|
    t.bigint "careplus_report_id", null: false
    t.integer "change_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vaccination_record_id", null: false
    t.index ["careplus_report_id"], name: "idx_on_careplus_report_id_98876049c7"
    t.index ["vaccination_record_id"], name: "idx_on_vaccination_record_id_e7f05454ab"
  end

  create_table "careplus_reports", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.datetime "created_at", null: false
    t.text "csv_data"
    t.text "csv_filename"
    t.datetime "csv_removed_at"
    t.date "date_from", null: false
    t.date "date_to", null: false
    t.enum "programme_types", null: false, array: true, enum_type: "programme_type"
    t.datetime "scheduled_at", null: false
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["programme_types"], name: "index_careplus_reports_on_programme_types", using: :gin
    t.index ["status", "scheduled_at"], name: "index_careplus_reports_on_status_and_scheduled_at"
    t.index ["team_id", "academic_year"], name: "index_careplus_reports_on_team_id_and_academic_year"
    t.index ["team_id"], name: "index_careplus_reports_on_team_id"
  end

  create_table "class_imports", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.integer "changed_record_count"
    t.datetime "created_at", null: false
    t.text "csv_data"
    t.text "csv_filename"
    t.datetime "csv_removed_at"
    t.integer "exact_duplicate_record_count"
    t.bigint "location_id", null: false
    t.integer "new_record_count"
    t.datetime "processed_at"
    t.datetime "reviewed_at", default: [], null: false, array: true
    t.bigint "reviewed_by_user_ids", default: [], null: false, array: true
    t.integer "rows_count"
    t.jsonb "serialized_errors"
    t.integer "status", default: 0, null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "uploaded_by_user_id", null: false
    t.integer "year_groups", default: [], null: false, array: true
    t.index ["location_id"], name: "index_class_imports_on_location_id"
    t.index ["team_id"], name: "index_class_imports_on_team_id"
    t.index ["uploaded_by_user_id"], name: "index_class_imports_on_uploaded_by_user_id"
  end

  create_table "class_imports_parent_relationships", id: false, force: :cascade do |t|
    t.bigint "class_import_id", null: false
    t.bigint "parent_relationship_id", null: false
    t.index ["class_import_id", "parent_relationship_id"], name: "idx_on_class_import_id_parent_relationship_id_8225058195", unique: true
  end

  create_table "class_imports_parents", id: false, force: :cascade do |t|
    t.bigint "class_import_id", null: false
    t.bigint "parent_id", null: false
    t.index ["class_import_id", "parent_id"], name: "index_class_imports_parents_on_class_import_id_and_parent_id", unique: true
  end

  create_table "class_imports_patients", id: false, force: :cascade do |t|
    t.bigint "class_import_id", null: false
    t.bigint "patient_id", null: false
    t.index ["class_import_id", "patient_id"], name: "index_class_imports_patients_on_class_import_id_and_patient_id", unique: true
  end

  create_table "clinic_notifications", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.datetime "created_at", null: false
    t.bigint "patient_id", null: false
    t.enum "programme_types", null: false, array: true, enum_type: "programme_type"
    t.datetime "sent_at", null: false
    t.bigint "sent_by_user_id"
    t.bigint "team_id", null: false
    t.integer "type", null: false
    t.datetime "updated_at", null: false
    t.index ["academic_year"], name: "index_clinic_notifications_on_academic_year"
    t.index ["patient_id"], name: "index_clinic_notifications_on_patient_id"
    t.index ["programme_types"], name: "index_clinic_notifications_on_programme_types", using: :gin
    t.index ["sent_by_user_id"], name: "index_clinic_notifications_on_sent_by_user_id"
    t.index ["team_id"], name: "index_clinic_notifications_on_team_id"
  end

  create_table "cohort_imports", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.integer "changed_record_count"
    t.datetime "created_at", null: false
    t.text "csv_data"
    t.text "csv_filename"
    t.datetime "csv_removed_at"
    t.integer "exact_duplicate_record_count"
    t.integer "new_record_count"
    t.datetime "processed_at"
    t.datetime "reviewed_at", default: [], null: false, array: true
    t.bigint "reviewed_by_user_ids", default: [], null: false, array: true
    t.integer "rows_count"
    t.jsonb "serialized_errors"
    t.integer "status", default: 0, null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "uploaded_by_user_id", null: false
    t.index ["team_id"], name: "index_cohort_imports_on_team_id"
    t.index ["uploaded_by_user_id"], name: "index_cohort_imports_on_uploaded_by_user_id"
  end

  create_table "cohort_imports_parent_relationships", id: false, force: :cascade do |t|
    t.bigint "cohort_import_id", null: false
    t.bigint "parent_relationship_id", null: false
    t.index ["cohort_import_id", "parent_relationship_id"], name: "idx_on_cohort_import_id_parent_relationship_id_c65e20d1f8", unique: true
  end

  create_table "cohort_imports_parents", id: false, force: :cascade do |t|
    t.bigint "cohort_import_id", null: false
    t.bigint "parent_id", null: false
    t.index ["cohort_import_id", "parent_id"], name: "index_cohort_imports_parents_on_cohort_import_id_and_parent_id", unique: true
  end

  create_table "cohort_imports_patients", id: false, force: :cascade do |t|
    t.bigint "cohort_import_id", null: false
    t.bigint "patient_id", null: false
    t.index ["cohort_import_id", "patient_id"], name: "idx_on_cohort_import_id_patient_id_7864d1a8b0", unique: true
  end

  create_table "consent_form_programmes", force: :cascade do |t|
    t.bigint "consent_form_id", null: false
    t.enum "disease_types", array: true, enum_type: "disease_type"
    t.boolean "follow_up_requested"
    t.text "notes", default: "", null: false
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.integer "reason_for_refusal"
    t.integer "response"
    t.integer "vaccine_methods", default: [], null: false, array: true
    t.boolean "without_gelatine"
    t.index ["consent_form_id"], name: "index_consent_form_programmes_on_consent_form_id"
    t.index ["programme_type", "consent_form_id"], name: "idx_on_programme_type_consent_form_id_805eb5d685", unique: true
  end

  create_table "consent_forms", force: :cascade do |t|
    t.string "address_line_1"
    t.string "address_line_2"
    t.string "address_postcode"
    t.string "address_town"
    t.datetime "archived_at"
    t.datetime "confirmation_sent_at"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.integer "education_setting"
    t.integer "ethnic_background"
    t.string "ethnic_background_other"
    t.integer "ethnic_group"
    t.text "family_name"
    t.text "given_name"
    t.jsonb "health_answers", default: [], null: false
    t.string "nhs_number"
    t.text "notes", default: "", null: false
    t.bigint "original_session_id"
    t.string "parent_contact_method_other_details"
    t.string "parent_contact_method_type"
    t.string "parent_email"
    t.string "parent_full_name"
    t.string "parent_phone"
    t.boolean "parent_phone_receive_updates", default: false, null: false
    t.string "parent_relationship_other_name"
    t.string "parent_relationship_type"
    t.string "preferred_family_name"
    t.string "preferred_given_name"
    t.datetime "recorded_at"
    t.boolean "school_confirmed"
    t.bigint "school_id"
    t.bigint "team_location_id", null: false
    t.datetime "updated_at", null: false
    t.boolean "use_preferred_name"
    t.index ["id"], name: "index_consent_forms_on_recorded", where: "(recorded_at IS NOT NULL)"
    t.index ["id"], name: "index_consent_forms_on_unmatched_and_not_archived", where: "((recorded_at IS NOT NULL) AND (archived_at IS NULL))"
    t.index ["nhs_number"], name: "index_consent_forms_on_nhs_number"
    t.index ["original_session_id"], name: "index_consent_forms_on_original_session_id"
    t.index ["school_id"], name: "index_consent_forms_on_school_id"
    t.index ["team_location_id"], name: "index_consent_forms_on_team_location_id"
  end

  create_table "consent_notifications", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.enum "programme_types", null: false, array: true, enum_type: "programme_type"
    t.datetime "sent_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "sent_by_user_id"
    t.bigint "session_id"
    t.bigint "team_location_id", null: false
    t.integer "type", null: false
    t.index ["patient_id"], name: "index_consent_notifications_on_patient_id"
    t.index ["programme_types"], name: "index_consent_notifications_on_programme_types", using: :gin
    t.index ["sent_by_user_id"], name: "index_consent_notifications_on_sent_by_user_id"
    t.index ["session_id"], name: "index_consent_notifications_on_session_id"
    t.index ["team_location_id"], name: "index_consent_notifications_on_team_location_id"
  end

  create_table "consents", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.bigint "consent_form_id"
    t.datetime "created_at", null: false
    t.enum "disease_types", null: false, array: true, enum_type: "disease_type"
    t.integer "follow_up_outcome"
    t.boolean "follow_up_requested"
    t.datetime "follow_up_resolved_at"
    t.jsonb "health_answers", default: [], null: false
    t.datetime "invalidated_at"
    t.text "notes", default: "", null: false
    t.boolean "notify_parent_on_refusal"
    t.boolean "notify_parents_on_vaccination"
    t.string "parent_email"
    t.string "parent_full_name"
    t.bigint "parent_id"
    t.string "parent_phone"
    t.boolean "parent_phone_receive_updates"
    t.string "parent_relationship_other_name"
    t.string "parent_relationship_type"
    t.datetime "patient_already_vaccinated_notification_sent_at"
    t.bigint "patient_id", null: false
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.integer "reason_for_refusal"
    t.bigint "recorded_by_user_id"
    t.integer "response", null: false
    t.integer "route", null: false
    t.datetime "submitted_at", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.integer "vaccine_methods", default: [], null: false, array: true
    t.datetime "withdrawn_at"
    t.boolean "without_gelatine"
    t.index ["academic_year"], name: "index_consents_on_academic_year"
    t.index ["consent_form_id"], name: "index_consents_on_consent_form_id"
    t.index ["parent_id"], name: "index_consents_on_parent_id"
    t.index ["patient_id"], name: "index_consents_on_patient_id"
    t.index ["programme_type"], name: "index_consents_on_programme_type"
    t.index ["recorded_by_user_id"], name: "index_consents_on_recorded_by_user_id"
    t.index ["team_id"], name: "index_consents_on_team_id"
  end

  create_table "data_migrations", primary_key: "version", id: :string, force: :cascade do |t|
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "gillick_assessments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.boolean "knows_consequences", null: false
    t.boolean "knows_delivery", null: false
    t.boolean "knows_disease", null: false
    t.boolean "knows_side_effects", null: false
    t.boolean "knows_vaccination", null: false
    t.bigint "location_id", null: false
    t.text "notes", default: "", null: false
    t.bigint "patient_id", null: false
    t.bigint "performed_by_user_id", null: false
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_gillick_assessments_on_location_id"
    t.index ["patient_id"], name: "index_gillick_assessments_on_patient_id"
    t.index ["performed_by_user_id"], name: "index_gillick_assessments_on_performed_by_user_id"
    t.index ["programme_type"], name: "index_gillick_assessments_on_programme_type"
  end

  create_table "health_questions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "follow_up_question_id"
    t.string "give_details_hint"
    t.string "hint"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "next_question_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "vaccine_id", null: false
    t.boolean "would_require_triage", default: true, null: false
    t.index ["follow_up_question_id"], name: "index_health_questions_on_follow_up_question_id"
    t.index ["next_question_id"], name: "index_health_questions_on_next_question_id"
    t.index ["vaccine_id"], name: "index_health_questions_on_vaccine_id"
  end

  create_table "identity_checks", force: :cascade do |t|
    t.string "confirmed_by_other_name", default: "", null: false
    t.string "confirmed_by_other_relationship", default: "", null: false
    t.boolean "confirmed_by_patient", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vaccination_record_id", null: false
    t.index ["vaccination_record_id"], name: "index_identity_checks_on_vaccination_record_id"
  end

  create_table "immunisation_imports", force: :cascade do |t|
    t.integer "changed_record_count"
    t.datetime "created_at", null: false
    t.text "csv_data"
    t.text "csv_filename", null: false
    t.datetime "csv_removed_at"
    t.integer "exact_duplicate_record_count"
    t.integer "ignored_record_count"
    t.integer "new_record_count"
    t.datetime "processed_at"
    t.integer "rows_count"
    t.jsonb "serialized_errors"
    t.integer "status", default: 0, null: false
    t.bigint "team_id", null: false
    t.integer "type", null: false
    t.datetime "updated_at", null: false
    t.bigint "uploaded_by_user_id", null: false
    t.index ["team_id"], name: "index_immunisation_imports_on_team_id"
    t.index ["uploaded_by_user_id"], name: "index_immunisation_imports_on_uploaded_by_user_id"
  end

  create_table "immunisation_imports_patient_locations", id: false, force: :cascade do |t|
    t.bigint "immunisation_import_id", null: false
    t.bigint "patient_location_id", null: false
    t.index ["immunisation_import_id", "patient_location_id"], name: "idx_on_immunisation_import_id_patient_location_id_97ddfb7192", unique: true
  end

  create_table "immunisation_imports_patients", id: false, force: :cascade do |t|
    t.bigint "immunisation_import_id", null: false
    t.bigint "patient_id", null: false
    t.index ["immunisation_import_id", "patient_id"], name: "idx_on_immunisation_import_id_patient_id_6dc58d875d", unique: true
  end

  create_table "immunisation_imports_sessions", id: false, force: :cascade do |t|
    t.bigint "immunisation_import_id", null: false
    t.bigint "session_id", null: false
    t.index ["immunisation_import_id", "session_id"], name: "idx_on_immunisation_import_id_session_id_f8b87b9417", unique: true
  end

  create_table "immunisation_imports_vaccination_records", id: false, force: :cascade do |t|
    t.bigint "immunisation_import_id", null: false
    t.bigint "vaccination_record_id", null: false
    t.index ["immunisation_import_id", "vaccination_record_id"], name: "idx_on_immunisation_import_id_vaccination_record_id_588e859772", unique: true
  end

  create_table "important_notices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "dismissed_at"
    t.bigint "dismissed_by_user_id"
    t.bigint "patient_id", null: false
    t.datetime "recorded_at", null: false
    t.bigint "school_move_log_entry_id"
    t.bigint "team_id", null: false
    t.integer "type", null: false
    t.datetime "updated_at", null: false
    t.bigint "vaccination_record_id"
    t.index ["dismissed_by_user_id"], name: "index_important_notices_on_dismissed_by_user_id"
    t.index ["patient_id", "type", "recorded_at", "team_id"], name: "index_notices_on_patient_and_type_and_recorded_at_and_team", unique: true
    t.index ["patient_id"], name: "index_important_notices_on_patient_id"
    t.index ["school_move_log_entry_id"], name: "index_important_notices_on_school_move_log_entry_id"
    t.index ["team_id"], name: "index_important_notices_on_team_id"
    t.index ["vaccination_record_id"], name: "index_important_notices_on_vaccination_record_id"
  end

  create_table "local_authorities", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date"
    t.integer "gias_code"
    t.string "gov_uk_slug"
    t.string "gss_code"
    t.string "mhclg_code", null: false
    t.string "nation", null: false
    t.string "official_name", null: false
    t.string "region"
    t.string "short_name", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_local_authorities_on_created_at"
    t.index ["gias_code"], name: "index_local_authorities_on_gias_code", unique: true
    t.index ["gss_code"], name: "index_local_authorities_on_gss_code", unique: true
    t.index ["mhclg_code"], name: "index_local_authorities_on_mhclg_code", unique: true
    t.index ["nation", "short_name"], name: "index_local_authorities_on_nation_and_short_name"
    t.index ["short_name"], name: "index_local_authorities_on_short_name"
  end

  create_table "local_authority_postcodes", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "gss_code", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["gss_code"], name: "index_local_authority_postcodes_on_gss_code"
    t.index ["value"], name: "index_local_authority_postcodes_on_value", unique: true
  end

  create_table "location_programme_year_groups", force: :cascade do |t|
    t.bigint "location_year_group_id", null: false
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.index ["location_year_group_id", "programme_type"], name: "idx_on_location_year_group_id_programme_type_904fa3b284", unique: true
    t.index ["location_year_group_id"], name: "index_location_programme_year_groups_on_location_year_group_id"
    t.index ["programme_type"], name: "index_location_programme_year_groups_on_programme_type"
  end

  create_table "location_year_groups", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.datetime "created_at", null: false
    t.bigint "location_id", null: false
    t.integer "source", null: false
    t.datetime "updated_at", null: false
    t.integer "value", null: false
    t.index ["location_id", "academic_year", "value"], name: "idx_on_location_id_academic_year_value_d553b03752", unique: true
    t.index ["location_id"], name: "index_location_year_groups_on_location_id"
  end

  create_table "locations", force: :cascade do |t|
    t.text "address_line_1"
    t.text "address_line_2"
    t.text "address_postcode"
    t.text "address_town"
    t.datetime "created_at", null: false
    t.integer "gias_establishment_number"
    t.integer "gias_local_authority_code"
    t.integer "gias_phase"
    t.integer "gias_year_groups", default: [], null: false, array: true
    t.text "name", null: false
    t.string "ods_code"
    t.geography "position", limit: {srid: 4326, type: "st_point", geographic: true}
    t.string "site"
    t.integer "status", default: 0, null: false
    t.string "systm_one_code"
    t.integer "type", null: false
    t.datetime "updated_at", null: false
    t.text "url"
    t.string "urn"
    t.index ["ods_code"], name: "index_locations_on_ods_code", unique: true
    t.index ["systm_one_code"], name: "index_locations_on_systm_one_code", unique: true
    t.index ["urn", "site"], name: "index_locations_on_urn_and_site", unique: true
    t.index ["urn"], name: "index_locations_on_urn", unique: true, where: "((type = 0) AND (site IS NULL))"
  end

  create_table "notes", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_notes_on_created_by_user_id"
    t.index ["patient_id"], name: "index_notes_on_patient_id"
    t.index ["session_id"], name: "index_notes_on_session_id"
  end

  create_table "notify_log_entries", force: :cascade do |t|
    t.text "body"
    t.bigint "consent_form_id"
    t.datetime "created_at", null: false
    t.uuid "delivery_id"
    t.integer "delivery_status", default: 0, null: false
    t.bigint "parent_id"
    t.bigint "patient_id"
    t.integer "purpose"
    t.string "recipient", null: false
    t.bigint "sent_by_user_id"
    t.text "subject"
    t.uuid "template_id", null: false
    t.integer "type", null: false
    t.index ["consent_form_id"], name: "index_notify_log_entries_on_consent_form_id"
    t.index ["delivery_id"], name: "index_notify_log_entries_on_delivery_id"
    t.index ["parent_id"], name: "index_notify_log_entries_on_parent_id"
    t.index ["patient_id"], name: "index_notify_log_entries_on_patient_id"
    t.index ["sent_by_user_id"], name: "index_notify_log_entries_on_sent_by_user_id"
  end

  create_table "notify_log_entry_programmes", primary_key: ["notify_log_entry_id", "programme_type"], force: :cascade do |t|
    t.enum "disease_types", null: false, array: true, enum_type: "disease_type"
    t.bigint "notify_log_entry_id", null: false
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.index ["notify_log_entry_id"], name: "index_notify_log_entry_programmes_on_notify_log_entry_id"
  end

  create_table "organisations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ods_code", null: false
    t.datetime "updated_at", null: false
    t.index ["ods_code"], name: "index_organisations_on_ods_code", unique: true
  end

  create_table "parent_relationships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "other_name"
    t.bigint "parent_id", null: false
    t.bigint "patient_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id", "patient_id"], name: "index_parent_relationships_on_parent_id_and_patient_id", unique: true
    t.index ["patient_id"], name: "index_parent_relationships_on_patient_id"
  end

  create_table "parents", force: :cascade do |t|
    t.text "contact_method_other_details"
    t.string "contact_method_type"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "full_name"
    t.string "phone"
    t.boolean "phone_receive_updates", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_parents_on_email"
  end

  create_table "patient_changesets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.bigint "import_id", null: false
    t.string "import_type", null: false
    t.boolean "matched_on_nhs_number"
    t.bigint "patient_id"
    t.string "pds_nhs_number"
    t.datetime "processed_at"
    t.integer "record_type", default: 1, null: false
    t.integer "row_number"
    t.bigint "school_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "uploaded_nhs_number"
    t.index ["import_type", "import_id"], name: "index_patient_changesets_on_import"
    t.index ["patient_id"], name: "index_patient_changesets_on_patient_id"
    t.index ["status"], name: "index_patient_changesets_on_status"
  end

  create_table "patient_locations", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.datetime "created_at", null: false
    t.daterange "date_range", default: -::Float::INFINITY...::Float::INFINITY, null: false
    t.bigint "location_id", null: false
    t.bigint "patient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id", "academic_year", "patient_id"], name: "idx_on_location_id_academic_year_patient_id_3237b32fa0", unique: true
    t.index ["location_id", "academic_year"], name: "index_patient_locations_on_location_id_and_academic_year"
    t.index ["location_id"], name: "index_patient_locations_on_location_id"
    t.index ["patient_id", "location_id", "academic_year"], name: "idx_on_patient_id_location_id_academic_year_08a1dc4afe", unique: true
  end

  create_table "patient_merge_log_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "merged_patient_dob", null: false
    t.bigint "merged_patient_id", null: false
    t.string "merged_patient_name", null: false
    t.string "merged_patient_nhs_number", null: false
    t.bigint "patient_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["patient_id"], name: "index_patient_merge_log_entries_on_patient_id"
    t.index ["user_id"], name: "index_patient_merge_log_entries_on_user_id"
  end

  create_table "patient_programme_statuses", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.integer "consent_status", default: 0, null: false
    t.integer "consent_vaccine_methods", default: [], null: false, array: true
    t.date "date"
    t.enum "disease_types", array: true, enum_type: "disease_type"
    t.integer "dose_sequence"
    t.bigint "location_id"
    t.bigint "patient_id", null: false
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.integer "status", default: 0, null: false
    t.integer "vaccine_methods", array: true
    t.boolean "without_gelatine"
    t.index ["academic_year", "patient_id"], name: "idx_on_academic_year_patient_id_3d5bf8d2c8"
    t.index ["location_id"], name: "index_patient_programme_statuses_on_location_id"
    t.index ["patient_id", "academic_year", "programme_type"], name: "idx_on_patient_id_academic_year_programme_type_75e0e0c471", unique: true
    t.index ["patient_id"], name: "index_patient_programme_statuses_on_patient_id"
    t.index ["status"], name: "index_patient_programme_statuses_on_status"
  end

  create_table "patient_programme_vaccinations_searches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_searched_at", null: false
    t.bigint "patient_id", null: false
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.datetime "updated_at", null: false
    t.index ["last_searched_at"], name: "idx_on_last_searched_at_96aaa59442"
    t.index ["patient_id"], name: "index_patient_programme_vaccinations_searches_on_patient_id"
    t.index ["programme_type"], name: "idx_on_programme_type_0d0cfaeb86"
  end

  create_table "patient_registration_statuses", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.bigint "session_id", null: false
    t.integer "status", default: 0, null: false
    t.index ["patient_id", "session_id"], name: "idx_on_patient_id_session_id_2ff02d8889", unique: true
    t.index ["patient_id"], name: "index_patient_registration_statuses_on_patient_id"
    t.index ["session_id"], name: "index_patient_registration_statuses_on_session_id"
    t.index ["status"], name: "index_patient_registration_statuses_on_status"
  end

  create_table "patient_specific_directions", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.integer "delivery_site", null: false
    t.datetime "invalidated_at"
    t.bigint "patient_id", null: false
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vaccine_id", null: false
    t.integer "vaccine_method", null: false
    t.index ["academic_year"], name: "index_patient_specific_directions_on_academic_year"
    t.index ["created_by_user_id"], name: "index_patient_specific_directions_on_created_by_user_id"
    t.index ["patient_id"], name: "index_patient_specific_directions_on_patient_id"
    t.index ["programme_type"], name: "index_patient_specific_directions_on_programme_type"
    t.index ["team_id"], name: "index_patient_specific_directions_on_team_id"
    t.index ["vaccine_id"], name: "index_patient_specific_directions_on_vaccine_id"
  end

  create_table "patient_teams", primary_key: ["team_id", "patient_id"], force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.integer "sources", null: false, array: true
    t.bigint "team_id", null: false
    t.index ["patient_id", "team_id"], name: "index_patient_teams_on_patient_id_and_team_id"
    t.index ["patient_id"], name: "index_patient_teams_on_patient_id"
    t.index ["sources"], name: "index_patient_teams_on_sources", using: :gin
    t.index ["team_id"], name: "index_patient_teams_on_team_id"
  end

  create_table "patients", force: :cascade do |t|
    t.string "address_line_1"
    t.string "address_line_2"
    t.string "address_postcode"
    t.string "address_town"
    t.integer "birth_academic_year", null: false
    t.datetime "created_at", null: false
    t.date "date_of_birth", null: false
    t.date "date_of_death"
    t.datetime "date_of_death_recorded_at"
    t.integer "ethnic_background"
    t.string "ethnic_background_other"
    t.integer "ethnic_group"
    t.string "family_name", null: false
    t.integer "gender_code", default: 0, null: false
    t.string "given_name", null: false
    t.bigint "gp_practice_id"
    t.datetime "invalidated_at"
    t.string "local_authority_mhclg_code"
    t.string "nhs_number"
    t.jsonb "pending_changes", default: {}, null: false
    t.string "preferred_family_name"
    t.string "preferred_given_name"
    t.string "registration"
    t.integer "registration_academic_year"
    t.datetime "restricted_at"
    t.bigint "school_id"
    t.datetime "updated_at", null: false
    t.datetime "updated_from_pds_at"
    t.index "address_postcode, date_of_birth, lower((given_name)::text)", name: "index_patients_on_lower_given_name_dob_address"
    t.index "date_of_birth, address_postcode, lower((family_name)::text)", name: "index_patients_on_lower_family_name_dob_address"
    t.index "lower((family_name)::text), lower((given_name)::text), address_postcode", name: "index_patients_on_lower_names_family_first_address"
    t.index "lower((given_name)::text), lower((family_name)::text), date_of_birth, address_postcode", name: "index_patients_on_lower_names_given_first_dob_address"
    t.index ["family_name", "given_name"], name: "index_patients_on_names_family_first"
    t.index ["family_name"], name: "index_patients_on_family_name_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["given_name", "family_name"], name: "index_patients_on_names_given_first"
    t.index ["given_name"], name: "index_patients_on_given_name_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["gp_practice_id"], name: "index_patients_on_gp_practice_id"
    t.index ["id"], name: "index_patients_on_pending_changes_not_empty", where: "(pending_changes <> '{}'::jsonb)"
    t.index ["local_authority_mhclg_code"], name: "index_patients_on_local_authority_mhclg_code"
    t.index ["nhs_number"], name: "index_patients_on_nhs_number", unique: true
    t.index ["school_id"], name: "index_patients_on_school_id"
  end

  create_table "pds_search_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "import_id"
    t.string "import_type"
    t.string "nhs_number"
    t.bigint "patient_id", null: false
    t.integer "result", null: false
    t.integer "step", null: false
    t.datetime "updated_at", null: false
    t.index ["import_type", "import_id"], name: "index_pds_search_results_on_import"
    t.index ["patient_id"], name: "index_pds_search_results_on_patient_id"
  end

  create_table "pre_screenings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.enum "disease_types", null: false, array: true, enum_type: "disease_type"
    t.bigint "location_id", null: false
    t.text "notes", default: "", null: false
    t.bigint "patient_id", null: false
    t.bigint "performed_by_user_id", null: false
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_pre_screenings_on_location_id"
    t.index ["patient_id"], name: "index_pre_screenings_on_patient_id"
    t.index ["performed_by_user_id"], name: "index_pre_screenings_on_performed_by_user_id"
    t.index ["programme_type"], name: "index_pre_screenings_on_programme_type"
  end

  create_table "reporting_api_one_time_tokens", primary_key: "token", id: :string, force: :cascade do |t|
    t.jsonb "cis2_info", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_reporting_api_one_time_tokens_on_created_at"
    t.index ["token"], name: "index_reporting_api_one_time_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_reporting_api_one_time_tokens_on_user_id", unique: true
  end

  create_table "school_move_log_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "home_educated"
    t.bigint "patient_id", null: false
    t.bigint "school_id"
    t.bigint "team_id"
    t.bigint "user_id"
    t.index ["patient_id"], name: "index_school_move_log_entries_on_patient_id"
    t.index ["school_id"], name: "index_school_move_log_entries_on_school_id"
    t.index ["team_id"], name: "index_school_move_log_entries_on_team_id"
    t.index ["user_id"], name: "index_school_move_log_entries_on_user_id"
  end

  create_table "school_moves", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.datetime "created_at", null: false
    t.bigint "patient_id", null: false
    t.bigint "school_id", null: false
    t.integer "source", null: false
    t.datetime "updated_at", null: false
    t.index ["patient_id", "school_id"], name: "index_school_moves_on_patient_id_and_school_id"
    t.index ["patient_id"], name: "index_school_moves_on_patient_id", unique: true
    t.index ["school_id"], name: "index_school_moves_on_school_id"
  end

  create_table "session_notifications", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.datetime "sent_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "sent_by_user_id"
    t.date "session_date", null: false
    t.bigint "session_id", null: false
    t.integer "type", null: false
    t.index ["patient_id", "session_id", "session_date"], name: "idx_on_patient_id_session_id_session_date_f7f30a3aa3"
    t.index ["sent_by_user_id"], name: "index_session_notifications_on_sent_by_user_id"
    t.index ["session_id"], name: "index_session_notifications_on_session_id"
  end

  create_table "session_programme_year_groups", primary_key: ["session_id", "programme_type", "year_group"], force: :cascade do |t|
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.bigint "session_id", null: false
    t.integer "year_group", null: false
    t.index ["session_id"], name: "index_session_programme_year_groups_on_session_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "dates", null: false, array: true
    t.integer "days_before_consent_reminders"
    t.boolean "national_protocol_enabled", default: false, null: false
    t.boolean "outbreak", default: false, null: false
    t.boolean "psd_enabled", default: false, null: false
    t.boolean "requires_registration", default: true, null: false
    t.date "send_consent_requests_at"
    t.string "slug", null: false
    t.bigint "team_location_id", null: false
    t.datetime "updated_at", null: false
    t.index ["dates"], name: "index_sessions_on_dates", using: :gin
    t.index ["team_location_id"], name: "index_sessions_on_team_location_id"
  end

  create_table "subteams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "phone", null: false
    t.string "phone_instructions"
    t.uuid "reply_to_id"
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "name"], name: "index_subteams_on_team_id_and_name", unique: true
  end

  create_table "team_locations", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.datetime "created_at", null: false
    t.bigint "location_id", null: false
    t.bigint "subteam_id"
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_team_locations_on_location_id"
    t.index ["subteam_id"], name: "index_team_locations_on_subteam_id"
    t.index ["team_id", "academic_year", "location_id"], name: "idx_on_team_id_academic_year_location_id_1717f14a0c", unique: true
    t.index ["team_id"], name: "index_team_locations_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "careplus_namespace"
    t.string "careplus_password"
    t.string "careplus_staff_code"
    t.string "careplus_staff_type"
    t.string "careplus_username"
    t.string "careplus_venue_code"
    t.datetime "created_at", null: false
    t.integer "days_before_consent_reminders", default: 7, null: false
    t.integer "days_before_consent_requests", default: 21, null: false
    t.string "email"
    t.text "name", null: false
    t.date "national_reporting_cut_off_date"
    t.bigint "organisation_id", null: false
    t.string "phone"
    t.string "phone_instructions"
    t.string "privacy_notice_url"
    t.string "privacy_policy_url"
    t.enum "programme_types", null: false, array: true, enum_type: "programme_type"
    t.uuid "reply_to_id"
    t.integer "type", null: false
    t.datetime "updated_at", null: false
    t.string "workgroup", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
    t.index ["organisation_id"], name: "index_teams_on_organisation_id"
    t.index ["programme_types"], name: "index_teams_on_programme_types", using: :gin
    t.index ["workgroup"], name: "index_teams_on_workgroup", unique: true
  end

  create_table "teams_users", id: false, force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "user_id", null: false
    t.index ["team_id", "user_id"], name: "index_teams_users_on_team_id_and_user_id"
    t.index ["user_id", "team_id"], name: "index_teams_users_on_user_id_and_team_id"
  end

  create_table "triages", force: :cascade do |t|
    t.integer "academic_year", null: false
    t.datetime "created_at", null: false
    t.date "delay_vaccination_until"
    t.enum "disease_types", null: false, array: true, enum_type: "disease_type"
    t.datetime "invalidated_at"
    t.text "notes", default: "", null: false
    t.bigint "patient_id", null: false
    t.bigint "performed_by_user_id"
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.integer "status", null: false
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.integer "vaccine_method"
    t.boolean "without_gelatine"
    t.index ["academic_year"], name: "index_triages_on_academic_year"
    t.index ["patient_id"], name: "index_triages_on_patient_id"
    t.index ["performed_by_user_id"], name: "index_triages_on_performed_by_user_id"
    t.index ["programme_type"], name: "index_triages_on_programme_type"
    t.index ["team_id"], name: "index_triages_on_team_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.integer "fallback_role"
    t.string "family_name", null: false
    t.string "given_name", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "provider"
    t.datetime "remember_created_at"
    t.string "reporting_api_session_token"
    t.string "session_token"
    t.boolean "show_in_suppliers", default: false, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reporting_api_session_token"], name: "index_users_on_reporting_api_session_token", unique: true
  end

  create_table "vaccination_records", force: :cascade do |t|
    t.date "batch_expiry"
    t.string "batch_number"
    t.datetime "confirmation_sent_at"
    t.datetime "created_at", null: false
    t.integer "delivery_method"
    t.integer "delivery_site"
    t.datetime "discarded_at"
    t.enum "disease_types", null: false, array: true, enum_type: "disease_type"
    t.integer "dose_sequence"
    t.bigint "duplicate_of_vaccination_record_id"
    t.boolean "full_dose"
    t.string "local_patient_id"
    t.string "local_patient_id_uri"
    t.bigint "location_id"
    t.string "location_name"
    t.bigint "next_dose_delay_triage_id"
    t.string "nhs_immunisations_api_etag"
    t.string "nhs_immunisations_api_id"
    t.string "nhs_immunisations_api_identifier_system"
    t.string "nhs_immunisations_api_identifier_value"
    t.boolean "nhs_immunisations_api_primary_source"
    t.datetime "nhs_immunisations_api_recorded_at"
    t.string "nhs_immunisations_api_snomed_procedure_code"
    t.string "nhs_immunisations_api_snomed_procedure_term"
    t.string "nhs_immunisations_api_snomed_product_code"
    t.string "nhs_immunisations_api_snomed_product_term"
    t.string "nhs_immunisations_api_snomed_reason_code"
    t.string "nhs_immunisations_api_snomed_reason_term"
    t.datetime "nhs_immunisations_api_sync_pending_at"
    t.datetime "nhs_immunisations_api_synced_at"
    t.text "notes"
    t.boolean "notify_parents"
    t.integer "outcome", null: false
    t.bigint "patient_id", null: false
    t.jsonb "pending_changes", default: {}, null: false
    t.date "performed_at_date", null: false
    t.time "performed_at_time"
    t.string "performed_by_family_name"
    t.string "performed_by_given_name"
    t.bigint "performed_by_user_id"
    t.string "performed_ods_code"
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.integer "protocol"
    t.bigint "reported_by_id"
    t.bigint "session_id"
    t.integer "source", null: false
    t.bigint "supplied_by_user_id"
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "vaccine_id"
    t.index ["discarded_at"], name: "index_vaccination_records_on_discarded_at"
    t.index ["duplicate_of_vaccination_record_id"], name: "idx_on_duplicate_of_vaccination_record_id_5071adce87"
    t.index ["id"], name: "index_vaccination_records_on_pending_changes_not_empty", where: "(pending_changes <> '{}'::jsonb)"
    t.index ["location_id"], name: "index_vaccination_records_on_location_id"
    t.index ["next_dose_delay_triage_id"], name: "index_vaccination_records_on_next_dose_delay_triage_id"
    t.index ["nhs_immunisations_api_id"], name: "index_vaccination_records_on_nhs_immunisations_api_id", unique: true
    t.index ["patient_id", "programme_type", "outcome"], name: "idx_on_patient_id_programme_type_outcome_453b557b54", where: "(discarded_at IS NULL)"
    t.index ["patient_id", "session_id"], name: "index_vaccination_records_on_patient_id_and_session_id"
    t.index ["patient_id"], name: "index_vaccination_records_on_patient_id"
    t.index ["performed_by_user_id"], name: "index_vaccination_records_on_performed_by_user_id"
    t.index ["performed_ods_code", "patient_id"], name: "index_vaccination_records_on_performed_ods_code_and_patient_id", where: "(session_id IS NULL)"
    t.index ["programme_type"], name: "index_vaccination_records_on_programme_type"
    t.index ["reported_by_id"], name: "index_vaccination_records_on_reported_by_id"
    t.index ["session_id"], name: "index_vaccination_records_on_session_id"
    t.index ["supplied_by_user_id"], name: "index_vaccination_records_on_supplied_by_user_id"
    t.index ["uuid"], name: "index_vaccination_records_on_uuid", unique: true
    t.index ["vaccine_id"], name: "index_vaccination_records_on_vaccine_id"
  end

  create_table "vaccines", force: :cascade do |t|
    t.text "brand", null: false
    t.boolean "contains_gelatine", null: false
    t.datetime "created_at", null: false
    t.boolean "discontinued", default: false, null: false
    t.enum "disease_types", default: [], null: false, array: true, enum_type: "disease_type"
    t.decimal "dose_volume_ml", null: false
    t.text "manufacturer", null: false
    t.integer "method", null: false
    t.string "nivs_name"
    t.enum "programme_type", null: false, enum_type: "programme_type"
    t.integer "side_effects", default: [], null: false, array: true
    t.string "snomed_product_code", null: false
    t.string "snomed_product_term", null: false
    t.datetime "updated_at", null: false
    t.text "upload_name", null: false
    t.index ["manufacturer", "brand"], name: "index_vaccines_on_manufacturer_and_brand", unique: true
    t.index ["programme_type"], name: "index_vaccines_on_programme_type"
    t.index ["snomed_product_code"], name: "index_vaccines_on_snomed_product_code", unique: true
    t.index ["snomed_product_term"], name: "index_vaccines_on_snomed_product_term", unique: true
    t.index ["upload_name"], name: "index_vaccines_on_upload_name", unique: true
  end

  add_foreign_key "access_log_entries", "users"
  add_foreign_key "archive_reasons", "patients"
  add_foreign_key "archive_reasons", "teams"
  add_foreign_key "archive_reasons", "users", column: "created_by_user_id"
  add_foreign_key "attendance_records", "locations"
  add_foreign_key "attendance_records", "patients"
  add_foreign_key "batches", "teams"
  add_foreign_key "batches", "vaccines"
  add_foreign_key "careplus_report_vaccination_records", "careplus_reports", on_delete: :cascade
  add_foreign_key "careplus_report_vaccination_records", "vaccination_records"
  add_foreign_key "careplus_reports", "teams"
  add_foreign_key "class_imports", "locations"
  add_foreign_key "class_imports", "teams"
  add_foreign_key "class_imports", "users", column: "uploaded_by_user_id"
  add_foreign_key "class_imports_parent_relationships", "class_imports", on_delete: :cascade
  add_foreign_key "class_imports_parent_relationships", "parent_relationships", on_delete: :cascade
  add_foreign_key "class_imports_parents", "class_imports", on_delete: :cascade
  add_foreign_key "class_imports_parents", "parents", on_delete: :cascade
  add_foreign_key "class_imports_patients", "class_imports", on_delete: :cascade
  add_foreign_key "class_imports_patients", "patients", on_delete: :cascade
  add_foreign_key "clinic_notifications", "patients"
  add_foreign_key "clinic_notifications", "teams"
  add_foreign_key "clinic_notifications", "users", column: "sent_by_user_id"
  add_foreign_key "cohort_imports", "teams"
  add_foreign_key "cohort_imports", "users", column: "uploaded_by_user_id"
  add_foreign_key "cohort_imports_parent_relationships", "cohort_imports", on_delete: :cascade
  add_foreign_key "cohort_imports_parent_relationships", "parent_relationships", on_delete: :cascade
  add_foreign_key "cohort_imports_parents", "cohort_imports", on_delete: :cascade
  add_foreign_key "cohort_imports_parents", "parents", on_delete: :cascade
  add_foreign_key "cohort_imports_patients", "cohort_imports", on_delete: :cascade
  add_foreign_key "cohort_imports_patients", "patients", on_delete: :cascade
  add_foreign_key "consent_form_programmes", "consent_forms", on_delete: :cascade
  add_foreign_key "consent_forms", "locations", column: "school_id"
  add_foreign_key "consent_forms", "sessions", column: "original_session_id"
  add_foreign_key "consent_forms", "team_locations"
  add_foreign_key "consent_notifications", "patients"
  add_foreign_key "consent_notifications", "sessions"
  add_foreign_key "consent_notifications", "users", column: "sent_by_user_id"
  add_foreign_key "consents", "consent_forms"
  add_foreign_key "consents", "parents"
  add_foreign_key "consents", "patients"
  add_foreign_key "consents", "teams"
  add_foreign_key "consents", "users", column: "recorded_by_user_id"
  add_foreign_key "gillick_assessments", "locations"
  add_foreign_key "gillick_assessments", "patients"
  add_foreign_key "gillick_assessments", "users", column: "performed_by_user_id"
  add_foreign_key "health_questions", "health_questions", column: "follow_up_question_id"
  add_foreign_key "health_questions", "health_questions", column: "next_question_id"
  add_foreign_key "health_questions", "vaccines"
  add_foreign_key "identity_checks", "vaccination_records", on_delete: :cascade
  add_foreign_key "immunisation_imports", "teams"
  add_foreign_key "immunisation_imports", "users", column: "uploaded_by_user_id"
  add_foreign_key "immunisation_imports_patient_locations", "immunisation_imports", on_delete: :cascade
  add_foreign_key "immunisation_imports_patient_locations", "patient_locations", on_delete: :cascade
  add_foreign_key "immunisation_imports_patients", "immunisation_imports", on_delete: :cascade
  add_foreign_key "immunisation_imports_patients", "patients", on_delete: :cascade
  add_foreign_key "immunisation_imports_sessions", "immunisation_imports", on_delete: :cascade
  add_foreign_key "immunisation_imports_sessions", "sessions", on_delete: :cascade
  add_foreign_key "immunisation_imports_vaccination_records", "immunisation_imports", on_delete: :cascade
  add_foreign_key "immunisation_imports_vaccination_records", "vaccination_records", on_delete: :cascade
  add_foreign_key "important_notices", "patients"
  add_foreign_key "important_notices", "school_move_log_entries"
  add_foreign_key "important_notices", "teams"
  add_foreign_key "important_notices", "users", column: "dismissed_by_user_id"
  add_foreign_key "important_notices", "vaccination_records"
  add_foreign_key "location_programme_year_groups", "location_year_groups", on_delete: :cascade
  add_foreign_key "location_year_groups", "locations", on_delete: :cascade
  add_foreign_key "notes", "patients"
  add_foreign_key "notes", "sessions"
  add_foreign_key "notes", "users", column: "created_by_user_id"
  add_foreign_key "notify_log_entries", "consent_forms"
  add_foreign_key "notify_log_entries", "parents", on_delete: :nullify
  add_foreign_key "notify_log_entries", "patients", on_delete: :cascade, validate: false
  add_foreign_key "notify_log_entries", "users", column: "sent_by_user_id"
  add_foreign_key "notify_log_entry_programmes", "notify_log_entries", on_delete: :cascade
  add_foreign_key "parent_relationships", "parents"
  add_foreign_key "parent_relationships", "patients"
  add_foreign_key "patient_changesets", "locations", column: "school_id"
  add_foreign_key "patient_changesets", "patients"
  add_foreign_key "patient_locations", "locations"
  add_foreign_key "patient_locations", "patients"
  add_foreign_key "patient_merge_log_entries", "patients", on_delete: :cascade, validate: false
  add_foreign_key "patient_merge_log_entries", "users"
  add_foreign_key "patient_programme_statuses", "patients", on_delete: :cascade
  add_foreign_key "patient_programme_vaccinations_searches", "patients", on_delete: :cascade, validate: false
  add_foreign_key "patient_registration_statuses", "patients", on_delete: :cascade
  add_foreign_key "patient_registration_statuses", "sessions", on_delete: :cascade
  add_foreign_key "patient_specific_directions", "patients"
  add_foreign_key "patient_specific_directions", "teams"
  add_foreign_key "patient_specific_directions", "users", column: "created_by_user_id"
  add_foreign_key "patient_specific_directions", "vaccines"
  add_foreign_key "patient_teams", "patients", on_delete: :cascade
  add_foreign_key "patient_teams", "teams", on_delete: :cascade
  add_foreign_key "patients", "locations", column: "gp_practice_id"
  add_foreign_key "patients", "locations", column: "school_id"
  add_foreign_key "pds_search_results", "patients", on_delete: :cascade, validate: false
  add_foreign_key "pre_screenings", "locations"
  add_foreign_key "pre_screenings", "patients"
  add_foreign_key "pre_screenings", "users", column: "performed_by_user_id"
  add_foreign_key "reporting_api_one_time_tokens", "users"
  add_foreign_key "school_move_log_entries", "locations", column: "school_id"
  add_foreign_key "school_move_log_entries", "patients", on_delete: :cascade, validate: false
  add_foreign_key "school_move_log_entries", "teams"
  add_foreign_key "school_move_log_entries", "users"
  add_foreign_key "school_moves", "locations", column: "school_id"
  add_foreign_key "school_moves", "patients"
  add_foreign_key "session_notifications", "patients"
  add_foreign_key "session_notifications", "sessions"
  add_foreign_key "session_notifications", "users", column: "sent_by_user_id"
  add_foreign_key "session_programme_year_groups", "sessions", on_delete: :cascade
  add_foreign_key "sessions", "team_locations"
  add_foreign_key "subteams", "teams"
  add_foreign_key "team_locations", "locations"
  add_foreign_key "team_locations", "subteams"
  add_foreign_key "team_locations", "teams"
  add_foreign_key "teams", "organisations"
  add_foreign_key "triages", "patients"
  add_foreign_key "triages", "teams"
  add_foreign_key "triages", "users", column: "performed_by_user_id"
  add_foreign_key "vaccination_records", "patients"
  add_foreign_key "vaccination_records", "sessions"
  add_foreign_key "vaccination_records", "triages", column: "next_dose_delay_triage_id"
  add_foreign_key "vaccination_records", "users", column: "performed_by_user_id"
  add_foreign_key "vaccination_records", "users", column: "reported_by_id"
  add_foreign_key "vaccination_records", "users", column: "supplied_by_user_id"
  add_foreign_key "vaccination_records", "vaccination_records", column: "duplicate_of_vaccination_record_id"
  add_foreign_key "vaccination_records", "vaccines"

  create_view "reporting_api_totals", materialized: true, sql_definition: <<-SQL
      SELECT ((((((((pps.patient_id || '-'::text) || pps.programme_type) || '-'::text) || tl.team_id) || '-'::text) || pl.location_id) || '-'::text) || pps.academic_year) AS id,
      pps.patient_id,
      pps.academic_year,
      pps.programme_type,
      pps.status,
      pps.consent_status,
      tl.team_id,
      pl.location_id AS session_location_id,
          CASE pat.gender_code
              WHEN 0 THEN 'not known'::text
              WHEN 1 THEN 'male'::text
              WHEN 2 THEN 'female'::text
              WHEN 9 THEN 'not specified'::text
              ELSE NULL::text
          END AS patient_gender,
      ((pps.academic_year - pat.birth_academic_year) - 5) AS patient_year_group,
      COALESCE(la.mhclg_code, pat.local_authority_mhclg_code, 'UNKNOWN'::character varying) AS patient_local_authority_code,
      COALESCE(la.official_name, pat_la.official_name, 'Unknown Local Authority'::character varying) AS patient_local_authority_official_name,
      COALESCE(la.mhclg_code, ''::character varying) AS patient_school_local_authority_code,
      COALESCE(school.urn, '888888'::character varying) AS patient_school_urn,
      COALESCE(school.name, 'Unknown school'::text) AS patient_school_name,
      (ar.patient_id IS NOT NULL) AS is_archived,
      (EXISTS ( SELECT 1
             FROM consents con
            WHERE ((con.patient_id = pps.patient_id) AND (con.programme_type = pps.programme_type) AND (con.academic_year = pps.academic_year) AND (con.invalidated_at IS NULL) AND (con.withdrawn_at IS NULL) AND (con.response = 1) AND (con.reason_for_refusal = 1)))) AS has_already_vaccinated_consent
     FROM (((((((patient_programme_statuses pps
       JOIN patients pat ON ((pat.id = pps.patient_id)))
       JOIN patient_locations pl ON (((pl.patient_id = pps.patient_id) AND (pl.academic_year = pps.academic_year))))
       JOIN team_locations tl ON (((tl.location_id = pl.location_id) AND (tl.academic_year = pps.academic_year))))
       LEFT JOIN archive_reasons ar ON (((ar.patient_id = pps.patient_id) AND (ar.team_id = tl.team_id))))
       LEFT JOIN locations school ON ((school.id = pat.school_id)))
       LEFT JOIN local_authorities la ON ((la.gias_code = school.gias_local_authority_code)))
       LEFT JOIN local_authorities pat_la ON (((pat_la.mhclg_code)::text = (pat.local_authority_mhclg_code)::text)))
    WHERE ((pat.invalidated_at IS NULL) AND (pat.restricted_at IS NULL) AND (pat.date_of_death IS NULL));
  SQL
  add_index "reporting_api_totals", ["id"], name: "ix_rapi_totals_id", unique: true
  add_index "reporting_api_totals", ["patient_year_group"], name: "ix_rapi_totals_year_group"
  add_index "reporting_api_totals", ["session_location_id"], name: "ix_rapi_totals_session_loc"
  add_index "reporting_api_totals", ["team_id", "academic_year", "programme_type", "status"], name: "ix_rapi_totals_team_year_prog_status"

end
