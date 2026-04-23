# frozen_string_literal: true

# == Schema Information
#
# Table name: patients
#
#  id                         :bigint           not null, primary key
#  address_line_1             :string
#  address_line_2             :string
#  address_postcode           :string
#  address_town               :string
#  birth_academic_year        :integer          not null
#  date_of_birth              :date             not null
#  date_of_death              :date
#  date_of_death_recorded_at  :datetime
#  ethnic_background          :integer
#  ethnic_background_other    :string
#  ethnic_group               :integer
#  family_name                :string           not null
#  gender_code                :integer          default("not_known"), not null
#  given_name                 :string           not null
#  invalidated_at             :datetime
#  local_authority_mhclg_code :string
#  nhs_number                 :string
#  pending_changes            :jsonb            not null
#  preferred_family_name      :string
#  preferred_given_name       :string
#  registration               :string
#  registration_academic_year :integer
#  restricted_at              :datetime
#  updated_from_pds_at        :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  gp_practice_id             :bigint
#  school_id                  :bigint
#
# Indexes
#
#  index_patients_on_family_name_trigram                  (family_name) USING gin
#  index_patients_on_given_name_trigram                   (given_name) USING gin
#  index_patients_on_gp_practice_id                       (gp_practice_id)
#  index_patients_on_local_authority_mhclg_code           (local_authority_mhclg_code)
#  index_patients_on_lower_family_name_dob_address        (date_of_birth, address_postcode, lower((family_name)::text))
#  index_patients_on_lower_given_name_dob_address         (address_postcode, date_of_birth, lower((given_name)::text))
#  index_patients_on_lower_names_family_first_address     (lower((family_name)::text), lower((given_name)::text), address_postcode)
#  index_patients_on_lower_names_given_first_dob_address  (lower((given_name)::text), lower((family_name)::text), date_of_birth, address_postcode)
#  index_patients_on_names_family_first                   (family_name,given_name)
#  index_patients_on_names_given_first                    (given_name,family_name)
#  index_patients_on_nhs_number                           (nhs_number) UNIQUE
#  index_patients_on_pending_changes_not_empty            (id) WHERE (pending_changes <> '{}'::jsonb)
#  index_patients_on_school_id                            (school_id)
#
# Foreign Keys
#
#  fk_rails_...  (gp_practice_id => locations.id)
#  fk_rails_...  (school_id => locations.id)
#
class Patient < ApplicationRecord
  include AddressConcern
  include AgeConcern
  include EthnicityConcern
  include FullNameConcern
  include Invalidatable
  include PendingChangesConcern

  audited
  has_associated_audits

  belongs_to :gp_practice, class_name: "Location", optional: true
  belongs_to :school, class_name: "Location", optional: true

  has_many :access_log_entries
  has_many :archive_reasons
  has_many :attendance_records
  has_many :changesets, class_name: "PatientChangeset"
  has_many :clinic_notifications
  has_many :consent_notifications
  has_many :consents
  has_many :gillick_assessments
  has_many :important_notices, dependent: :destroy
  has_many :notes
  has_many :notify_log_entries
  has_many :parent_relationships, -> { order(:created_at) }
  has_many :patient_locations
  has_many :patient_merge_log_entries
  has_many :patient_programme_vaccinations_searches
  has_many :patient_specific_directions
  has_many :patient_teams
  has_many :pds_search_results
  has_many :pre_screenings
  has_many :programme_statuses
  has_many :registration_statuses
  has_many :school_move_log_entries
  has_many :school_moves
  has_many :session_notifications
  has_many :triages
  has_many :vaccination_records, -> { kept }

  has_many :locations, through: :patient_locations
  has_many :parents, through: :parent_relationships
  has_many :teams, through: :patient_teams

  has_and_belongs_to_many :class_imports
  has_and_belongs_to_many :cohort_imports
  has_and_belongs_to_many :immunisation_imports

  # https://www.datadictionary.nhs.uk/attributes/person_gender_code.html
  enum :gender_code, { not_known: 0, male: 1, female: 2, not_specified: 9 }

  # These are the statuses that a patient has to be in to be considered ready
  #  to vaccinate. The "cannot vaccinate" statuses occur if a patient is
  #  attempted to be vaccinated and then cannot be on the day for whatever
  #  reason, but we should be trying again to vaccinate these children.
  CONSENT_GIVEN_AND_SAFE_TO_VACCINATE_STATUSES = %w[
    due
    cannot_vaccinate_absent
    cannot_vaccinate_contraindicated
    cannot_vaccinate_refused
    cannot_vaccinate_unwell
  ].freeze

  scope :joins_sessions, -> { joins(:patient_locations).joins(<<-SQL) }
    INNER JOIN team_locations
    ON team_locations.location_id = patient_locations.location_id
    AND team_locations.academic_year = patient_locations.academic_year
    INNER JOIN sessions
    ON sessions.team_location_id = team_locations.id
    AND (sessions.dates = '{}' OR patient_locations.date_range @> ANY(sessions.dates))
  SQL

  scope :joins_session_programme_year_groups, -> { joins(<<-SQL) }
    INNER JOIN session_programme_year_groups
    ON session_programme_year_groups.session_id = sessions.id
    AND patients.birth_academic_year = team_locations.academic_year - session_programme_year_groups.year_group - #{Integer::AGE_CHILDREN_START_SCHOOL}
  SQL

  scope :archived,
        ->(team:) do
          joins(:patient_teams).where(
            patient_teams: {
              team_id: team.id
            }
          ).merge(PatientTeam.where_all_sources(%w[archive_reason]))
        end

  scope :not_archived,
        ->(team:) do
          joins(:patient_teams).where(
            patient_teams: {
              team_id: team.id
            }
          ).merge(PatientTeam.where_no_sources(%w[archive_reason]))
        end

  scope :with_pending_changes_for_team,
        ->(team:) { with_pending_changes.not_archived(team:) }

  scope :with_nhs_number, -> { where.not(nhs_number: nil) }
  scope :without_nhs_number, -> { where(nhs_number: nil) }

  scope :deceased, -> { where.not(date_of_death: nil) }
  scope :not_deceased, -> { where(date_of_death: nil) }
  scope :restricted, -> { where.not(restricted_at: nil) }

  scope :includes_statuses, -> { includes(:programme_statuses) }

  scope :has_vaccination_records_dont_notify_parents,
        -> do
          where(
            VaccinationRecord
              .kept
              .where("patient_id = patients.id")
              .where(notify_parents: false)
              .arel
              .exists
          )
        end

  scope :appear_in_programmes,
        ->(programmes, academic_year: nil, session: nil) do
          if session
            birth_academic_years =
              session
                .session_programme_year_groups
                .where(programme_type: programmes.map(&:type))
                .pluck_birth_academic_years

            where(birth_academic_year: birth_academic_years)
          elsif academic_year
            patient_locations =
              PatientLocation
                .select("1")
                .where("patient_locations.patient_id = patients.id")
                .where(academic_year:)
                .appear_in_programmes(programmes)

            where(patient_locations.arel.exists)
          else
            raise "Pass either academic year or session."
          end
        end

  scope :not_appear_in_programmes,
        ->(programmes, academic_year:) do
          patient_locations =
            PatientLocation
              .select("1")
              .where("patient_locations.patient_id = patients.id")
              .where(academic_year:)
              .appear_in_programmes(programmes)

          where.not(patient_locations.arel.exists)
        end

  scope :search_by_name_or_nhs_number,
        ->(query) do
          query_without_whitespace = query.gsub(/\s/, "")
          if query_without_whitespace.match?(/\A\d{10}\z/)
            return search_by_nhs_number(query_without_whitespace)
          end

          query = query.tr(",", " ")
          terms = query.split

          similarity_scope =
            terms.reduce(self) do |scope, term|
              scope.and where(
                          "family_name % :term OR given_name % :term",
                          term:
                        )
            end

          ilike_scope =
            terms.reduce(self) do |scope, term|
              if term.length < 3
                scope.and where(
                            "family_name ILIKE :term || '%' OR given_name ILIKE :term || '%'",
                            term:
                          )
              else
                scope.and where(
                            "family_name ILIKE '%' || :term || '%' OR given_name ILIKE '%' || :term || '%'",
                            term:
                          )
              end
            end

          similarity_scope.or(ilike_scope).order(
            Arel.sql(
              "(STRICT_WORD_SIMILARITY(given_name, :query) + STRICT_WORD_SIMILARITY(family_name, :query)) DESC",
              query:
            )
          )
        end

  scope :search_by_year_groups,
        ->(year_groups, academic_year:) do
          where(
            birth_academic_year:
              year_groups.map { it.to_birth_academic_year(academic_year:) }
          )
        end

  scope :search_by_date_of_birth_year,
        ->(year) { where("extract(year from date_of_birth) = ?", year) }

  scope :search_by_date_of_birth_month,
        ->(month) { where("extract(month from date_of_birth) = ?", month) }

  scope :search_by_date_of_birth_day,
        ->(day) { where("extract(day from date_of_birth) = ?", day) }

  scope :search_by_nhs_number, ->(nhs_number) { where(nhs_number:) }

  scope :has_programme_status,
        ->(status, programme:, academic_year:) do
          programme_status_scope =
            Patient::ProgrammeStatus
              .select("1")
              .where("patient_id = patients.id")
              .for_programmes(Array(programme))
              .where(status:, academic_year:)

          where(programme_status_scope.arel.exists)
        end

  scope :has_vaccine_criteria,
        ->(
          programme:,
          academic_year:,
          vaccine_methods: nil,
          without_gelatine: nil
        ) do
          programme_status_scope =
            Patient::ProgrammeStatus
              .select("1")
              .where("patient_id = patients.id")
              .for_programmes(Array(programme))
              .where(academic_year:)

          unless vaccine_methods.nil?
            if vaccine_methods.empty? ||
                 vaccine_methods.all? { it.is_a?(String) }
              programme_status_scope =
                programme_status_scope.where(
                  vaccine_methods:
                    vaccine_methods.map do
                      Patient::ProgrammeStatus.vaccine_methods.fetch(it)
                    end
                )
            else
              or_scope =
                programme_status_scope.where(
                  vaccine_methods:
                    vaccine_methods.first.map do
                      Patient::ProgrammeStatus.vaccine_methods.fetch(it)
                    end
                )

              vaccine_methods
                .drop(1)
                .each do |value|
                  or_scope =
                    or_scope.or(
                      programme_status_scope.where(
                        vaccine_methods:
                          value.map do
                            Patient::ProgrammeStatus.vaccine_methods.fetch(it)
                          end
                      )
                    )
                end

              programme_status_scope = or_scope
            end
          end

          unless without_gelatine.nil?
            programme_status_scope =
              programme_status_scope.where(without_gelatine:)
          end

          where(programme_status_scope.arel.exists)
        end

  scope :has_registration_status,
        ->(status, session:) do
          where(
            Patient::RegistrationStatus
              .select("1")
              .where("patient_id = patients.id")
              .where(session:, status:)
              .arel
              .exists
          )
        end

  scope :has_clinic_notification,
        ->(team:, academic_year:, programmes: []) do
          clinic_notification_scope =
            ClinicNotification
              .select("1")
              .where("patient_id = patients.id")
              .where(team:, academic_year:)

          if programmes.present?
            clinic_notification_scope =
              clinic_notification_scope.has_any_programmes_of(programmes)
          end

          where(clinic_notification_scope.arel.exists)
        end

  scope :with_patient_specific_direction,
        ->(programme:, academic_year:, team:) do
          where(
            PatientSpecificDirection
              .select("1")
              .where("patient_id = patients.id")
              .for_programmes(Array(programme))
              .where(academic_year:, team:)
              .not_invalidated
              .arel
              .exists
          )
        end

  scope :without_patient_specific_direction,
        ->(programme:, academic_year:, team:) do
          where.not(
            PatientSpecificDirection
              .select("1")
              .where("patient_id = patients.id")
              .for_programmes(Array(programme))
              .where(academic_year:, team:)
              .not_invalidated
              .arel
              .exists
          )
        end

  scope :consent_given_and_safe_to_vaccinate,
        ->(programmes:, academic_year:) do
          has_programme_status(
            CONSENT_GIVEN_AND_SAFE_TO_VACCINATE_STATUSES,
            programme: programmes,
            academic_year:
          )
        end

  scope :eligible_for_programme,
        ->(programme, session:) do
          # We exclude patients who were vaccinated in a previous
          # academic year, or vaccinated at a different location,
          # or the location is not known.

          academic_year = session.team_location.academic_year
          location = session.team_location.location

          # In the generic clinic sessions we have to show all patients even
          # if they were vaccinated elsewhere because the location of the
          # vaccination will be a specific community clinic location, not
          # the generic clinic.

          return self if location.generic_clinic? && programme.seasonal?

          programme_statuses =
            Patient::ProgrammeStatus
              .select("1")
              .where("patient_id = patients.id")
              .for_programme(programme)
              .vaccinated

          not_eligible_criteria =
            if location.generic_clinic?
              programme_statuses.where(academic_year: academic_year - 1)
            else
              scope =
                programme_statuses.where(academic_year:).where(
                  "location_id IS NULL OR location_id != ?",
                  location.id
                )

              unless programme.seasonal?
                scope =
                  scope.or(
                    programme_statuses.where(academic_year: academic_year - 1)
                  )
              end

              scope
            end

          where.not(not_eligible_criteria.arel.exists)
        end

  scope :eligible_for_any_programmes_of,
        ->(programmes, session:) do
          scope = eligible_for_programme(programmes.first, session:)

          programmes
            .drop(1)
            .each do |programme|
              scope = scope.or(eligible_for_programme(programme, session:))
            end

          scope
        end

  scope :with_team_searchable_in_nhs_immunisations_api,
        -> { joins(:teams).where.not(teams: { type: :national_reporting }) }

  validates :given_name, :family_name, :date_of_birth, presence: true

  validates :birth_academic_year, comparison: { greater_than_or_equal_to: 1990 }

  validates :nhs_number, nhs_number: true, uniqueness: true, allow_nil: true

  validates :address_postcode, postcode: { allow_nil: true }

  validate :locations_are_correct_type

  validates :birth_academic_year, comparison: { greater_than_or_equal_to: 1990 }

  encrypts :preferred_family_name,
           :preferred_given_name,
           :address_postcode,
           :nhs_number,
           deterministic: true

  encrypts :address_line_1, :address_line_2, :address_town

  normalizes :nhs_number,
             with: -> do
               it.blank? ? nil : it.normalise_whitespace.gsub(/\s/, "")
             end

  after_update :sync_vaccinations_to_nhs_immunisations_api
  after_commit :generate_important_notice_if_needed, on: :update
  after_commit :search_vaccinations_from_nhs_immunisations_api, on: :update
  before_destroy :destroy_childless_parents

  delegate :fhir_record, to: :fhir_mapper

  def sessions
    Session
      .joins_patient_locations
      .joins_patients
      .joins_session_programme_year_groups
      .where(patients: { id: })
      .distinct
  end

  def archived?(team_id:)
    if archive_reasons.loaded?
      archive_reasons.any? { it.team_id == team_id }
    else
      archive_reasons.exists?(team_id:)
    end
  end

  def not_archived?(team:)
    !archive_reasons.exists?(team:)
  end

  def year_group(academic_year:)
    birth_academic_year.to_year_group(academic_year:)
  end

  def year_group_changed? = birth_academic_year_changed?

  def show_year_group?(team:)
    return false if team.has_national_reporting_access?

    academic_year = AcademicYear.pending
    year_group = self.year_group(academic_year:)

    location_programme_year_groups =
      school&.location_programme_year_groups ||
        team.location_programme_year_groups

    team.programmes.any? do |programme|
      location_programme_year_groups.any? do
        it.programme_type == programme.type &&
          it.academic_year == academic_year && it.year_group == year_group
      end
    end
  end

  def can_self_consent_after_gillick_assessment?(location:, programme_type:)
    gillick_assessments
      .where(location:, programme_type:, date: Date.current)
      .order(created_at: :desc)
      &.first
      &.gillick_competent? || false
  end

  def programme_status(programme, academic_year:)
    # TODO: Update this method to accept the `programme_type` so that we can
    #  then determine the right programme variant from the `disease_types` on
    #  the `Patient::ProgrammeStatus`.
    programme_type = programme.type

    programme_statuses.find do
      it.programme_type == programme_type && it.academic_year == academic_year
    end || programme_statuses.build(programme_type:, academic_year:)
  end

  def registration_status(session:)
    registration_statuses.find { it.session_id == session.id } ||
      registration_statuses.build(session:)
  end

  def has_patient_specific_direction?(team:, **kwargs)
    patient_specific_directions.not_invalidated.where(team:, **kwargs).exists?
  end

  def consent_given_and_safe_to_vaccinate?(programme:, academic_year:)
    CONSENT_GIVEN_AND_SAFE_TO_VACCINATE_STATUSES.include?(
      programme_status(programme, academic_year:).status
    )
  end

  def vaccine_criteria(programme:, academic_year:)
    programme_status(programme, academic_year:).vaccine_criteria
  end

  def latest_delayed_triage(programme_types:)
    triages
      .not_invalidated
      .where(programme_type: programme_types)
      .delay_vaccination
      .order(created_at: :desc)
      .first
  end

  def eligible_for_mmrv?
    date_of_birth >= Programme::MIN_MMRV_ELIGIBILITY_DATE
  end

  def deceased? = date_of_death != nil

  def restricted? = restricted_at != nil

  def send_notifications?(team:, send_to_archived: false)
    !deceased? && !restricted? && !invalidated? &&
      (send_to_archived || not_archived?(team:))
  end

  ##
  # Check if a patient has been send a clinic invitation for a particular team
  # and academic year.
  #
  # This depends on the `clinic_notifications` association having already been
  # loaded.
  #
  # If multiple programmes are passed in, this method will only return `true`
  # if the patient has been invited for all the programmes.
  def invited_to_clinic?(programmes, team:, academic_year:)
    check_programme_types = programmes.map(&:type).uniq

    invited_programme_types =
      clinic_notifications
        .select { it.team_id == team.id && it.academic_year == academic_year }
        .flat_map(&:programme_types)
        .sort
        .uniq

    (check_programme_types - invited_programme_types).empty?
  end

  def update_from_pds!(pds_patient)
    if nhs_number.nil? || nhs_number != pds_patient.nhs_number
      raise NHSNumberMismatch
    end

    ActiveRecord::Base.transaction do
      self.date_of_death = pds_patient.date_of_death

      if date_of_death_changed?
        if date_of_death.present?
          archive_due_to_deceased!
          clear_pending_sessions!
        end

        self.date_of_death_recorded_at = Time.current
      end

      # If we've got a response from PDS we know the patient is valid,
      # otherwise PDS will return a 404 status.
      self.invalidated_at = nil if invalidated?

      if pds_patient.restricted
        self.restricted_at = Time.current unless restricted?
      else
        self.restricted_at = nil
      end

      if (ods_code = pds_patient.gp_ods_code).present?
        if (gp_practice = Location.gp_practice.find_by(ods_code:))
          self.gp_practice = gp_practice
        elsif Settings.pds.raise_unknown_gp_practice
          Sentry.capture_exception(UnknownGPPractice.new(ods_code))
        end
      else
        self.gp_practice = nil
      end

      self.updated_from_pds_at = Time.current

      save!
    end
  end

  def invalidate!
    return if invalidated?

    update!(invalidated_at: Time.current)
  end

  def not_in_team?(team:, academic_year:)
    if patient_locations.loaded?
      patient_locations.none? do |patloc|
        patloc.academic_year == academic_year &&
          patloc.location.team_locations.any? do |loc|
            loc.academic_year == academic_year && loc.team_id == team.id
          end
      end
    else
      patient_locations
        .where(academic_year:)
        .joins(location: :team_locations)
        .where(team_locations: { academic_year:, team: })
        .empty?
    end
  end

  def teams_via_patient_locations
    Team
      .joins(team_locations: { location: :patient_locations })
      .merge(
        PatientLocation.active.where(
          patient_id: id,
          academic_year: AcademicYear.current
        )
      )
      .distinct
  end

  def dup_for_pending_changes
    dup.tap do |new_patient|
      new_patient.nhs_number = nil

      patient_locations.pending.find_each do |patient_location|
        new_patient.patient_locations.build(
          academic_year: patient_location.academic_year,
          location_id: patient_location.location_id
        )
      end

      school_moves.each do |school_move|
        new_patient.school_moves.build(
          academic_year: school_move.academic_year,
          school_id: school_move.school_id,
          source: school_move.source
        )
      end

      patient_teams.find_each do |patient_team|
        # Patients that have been duplicated from another won't have any
        #  vaccination records or imports, therefore we need to filter the
        #  sources.
        sources = patient_team.sources & %w[patient_location school_move_school]

        new_patient.patient_teams.build(team_id: patient_team.team_id, sources:)
      end
    end
  end

  # This method overrides the implementation in `PendingChangesConcern`
  def apply_pending_changes_to_new_record!(changeset:)
    new_record = nil

    ActiveRecord::Base.transaction do
      new_record = super

      if changeset && new_record
        import = changeset.import

        # Parent relationships that were imported (and attached to the original
        # patient during matching) must move across to the duplicated patient.
        import
          .parent_relationships
          .where(patient_id: id)
          .update_all(patient_id: new_record.id)

        # Ensure the import itself is linked to the new patient record, not
        # the original one, so the import summary reflects what was created.
        import.patients.delete(self)
        import.patients << new_record
      end
    end

    new_record
  end

  def clear_pending_sessions!(team: nil)
    scope = patient_locations.pending

    unless team.nil?
      scope = scope.joins_sessions.where(team_locations: { team_id: team.id })
    end

    scope.find_each do |patient_location|
      patient_location.end_date = Date.current
      patient_location.save!
    end
  end

  def self.from_consent_form(consent_form)
    new(
      address_line_1: consent_form.address_line_1,
      address_line_2: consent_form.address_line_2,
      address_postcode: consent_form.address_postcode,
      address_town: consent_form.address_town,
      birth_academic_year: consent_form.date_of_birth.academic_year,
      date_of_birth: consent_form.date_of_birth,
      family_name: consent_form.family_name,
      given_name: consent_form.given_name,
      nhs_number: consent_form.nhs_number,
      preferred_family_name: consent_form.preferred_family_name,
      preferred_given_name: consent_form.preferred_given_name,
      school: consent_form.school_for_school_move
    )
  end

  class NHSNumberMismatch < StandardError
  end

  class UnknownGPPractice < StandardError
  end

  def latest_pds_search_result
    nhs_numbers =
      pds_search_results.latest_set&.pluck(:nhs_number)&.compact&.uniq
    nhs_numbers&.one? ? nhs_numbers.first : nil
  end

  def pds_lookup_match?
    nhs_number.present? && nhs_number == latest_pds_search_result
  end

  def notifier = Notifier::Patient.new(self)

  private

  def locations_are_correct_type
    if gp_practice && !gp_practice.gp_practice?
      errors.add(:gp_practice, "must be a GP practice location type")
    end

    if school && !school.school?
      errors.add(:school, "must be a school location type")
    end
  end

  def destroy_childless_parents
    parents_to_check = parents.to_a # Store parents before destroying relationships

    # Manually destroy the parent_relationships associated with this Child
    parent_relationships.each(&:destroy)

    parents_to_check.each do |parent|
      parent.destroy! if parent.parent_relationships.count.zero?
    end
  end

  def archive_due_to_deceased!
    archive_reasons =
      teams.map do |team|
        ArchiveReason.new(team:, patient: self, type: :deceased)
      end

    ArchiveReason.import!(
      archive_reasons,
      on_duplicate_key_update: {
        conflict_target: %i[team_id patient_id],
        columns: %i[type]
      }
    )

    PatientTeamUpdater.call(
      patient_scope: Patient.where(id:),
      team_scope: Team.where(id: team_ids)
    )
  end

  def fhir_mapper = @fhir_mapper ||= FHIRMapper::Patient.new(self)

  def should_sync_vaccinations_to_nhs_immunisations_api?
    nhs_number_previously_changed? || invalidated_at_previously_changed?
  end

  def sync_vaccinations_to_nhs_immunisations_api
    if should_sync_vaccinations_to_nhs_immunisations_api?
      vaccination_records.sync_all_to_nhs_immunisations_api
    end
  end

  def should_search_vaccinations_from_nhs_immunisations_api?
    nhs_number_previously_changed?
  end

  def search_vaccinations_from_nhs_immunisations_api
    if should_search_vaccinations_from_nhs_immunisations_api?
      SearchVaccinationRecordsInNHSJob.perform_async(id)
    end
  end

  def should_generate_important_notice?
    nhs_number_previously_changed? || invalidated_at_previously_changed? ||
      restricted_at_previously_changed? ||
      date_of_death_recorded_at_previously_changed?
  end

  def generate_important_notice_if_needed
    if should_generate_important_notice?
      ImportantNoticeGeneratorJob.perform_later([id])
    end
  end
end
