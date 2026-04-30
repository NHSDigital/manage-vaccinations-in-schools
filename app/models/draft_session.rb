# frozen_string_literal: true

class DraftSession
  include RequestSessionPersistable
  include EditableWrapper
  include WizardStepConcern

  include ActiveRecord::AttributeMethods::Serialization
  include Consentable
  include DaysBeforeToWeeksBefore
  include Delegatable

  attribute :academic_year, :integer
  attribute :days_before_consent_reminders, :integer
  attribute :location_id, :integer
  attribute :national_protocol_enabled, :boolean
  attribute :outbreak, :boolean
  attribute :programme_types, array: true, default: []
  attribute :psd_enabled, :boolean
  attribute :requires_registration, :boolean
  attribute :return_to, :string
  attribute :send_consent_requests_at, :date
  attribute :session_dates, array: true, default: []
  attribute :team_id, :integer
  attribute :year_groups, array: true, default: []

  serialize :session_dates, coder: DraftSessionDate::ArraySerializer

  def initialize(current_user:, **attributes)
    @current_user = current_user
    super(**attributes)
  end

  def wizard_steps
    steps = []

    steps << :school if new_record?

    steps << :programmes
    steps << :programmes_check
    steps << :year_groups if can_change_year_groups?

    steps << :dates
    steps << :dates_check if school?

    steps << :consent_style if supports_outbreak?

    if include_notification_steps? && school?
      steps += %i[consent_requests consent_reminders]
    end

    steps << :register_attendance

    steps << :delegation if supports_delegation?

    steps + %i[confirm]
  end

  on_wizard_step :school, exact: true do
    validates :location_id, inclusion: { in: :valid_school_ids }
  end

  on_wizard_step :programmes, exact: true do
    validates :programme_types, presence: true
    validate :cannot_remove_programmes
  end

  on_wizard_step :year_groups, exact: true do
    validates :year_groups, presence: true
  end

  on_wizard_step :dates, exact: true do
    validate :valid_session_dates
  end

  on_wizard_step :consent_requests, exact: true do
    validates :send_consent_requests_at,
              presence: true,
              comparison: {
                greater_than_or_equal_to: :earliest_send_notifications_at,
                less_than_or_equal_to: :latest_send_consent_requests_at
              }
  end

  on_wizard_step :consent_reminders, exact: true do
    validates :weeks_before_consent_reminders,
              presence: true,
              comparison: {
                greater_than_or_equal_to: 1,
                less_than_or_equal_to: :maximum_weeks_before_consent_reminders
              }
  end

  on_wizard_step :consent_style, exact: true do
    validates :outbreak, inclusion: [true, false]
  end

  def session
    return nil if editing_id.nil?

    @session ||=
      SessionPolicy::Scope.new(@current_user, Session).resolve.find(editing_id)
  end

  def session=(value)
    self.editing_id = value.id
  end

  def location
    return nil if location_id.nil?

    @location ||=
      LocationPolicy::Scope
        .new(@current_user, Location)
        .resolve
        .find(location_id)
  end

  def team
    return nil if team_id.nil?

    @team ||= TeamPolicy::Scope.new(@current_user, Team).resolve.find(team_id)
  end

  def team_location
    @team_location ||= TeamLocation.find_by!(team:, location:, academic_year:)
  end

  delegate :id, to: :team_location, prefix: true

  def school? = location&.gias_school?

  def generic_clinic? = location&.generic_clinic?

  def programmes = Programme.find_all(programme_types)

  def new_programmes = Programme.find_all(new_programme_types)

  def patient_locations
    @patient_locations ||=
      PatientLocation.where(school_id: location_id, academic_year:).includes(
        :patient
      )
  end

  def programme_types=(values)
    super(values&.compact_blank || [])
  end

  def year_groups=(values)
    super(values&.compact_blank&.filter_map(&:to_i) || [])
  end

  def session_programme_year_groups
    @session_programme_year_groups ||=
      location_programme_year_groups.filter_map do |location_programme_year_group|
        year_group = location_programme_year_group.year_group
        programme_type = location_programme_year_group.programme_type

        if programme_type.in?(programme_types) && year_group.in?(year_groups)
          Session::ProgrammeYearGroup.new(programme_type:, year_group:)
        end
      end
  end

  def programmes_for(year_group: nil, patient: nil)
    year_group ||= patient.year_group(academic_year:)

    programmes.select do |programme|
      session_programme_year_groups.any? do
        it.programme_type == programme.type && it.year_group == year_group
      end
    end
  end

  def patient_is_catch_up?(patient, programmes:)
    year_group = patient.year_group(academic_year:)
    programmes.any? { it.is_catch_up?(year_group:) }
  end

  def dates = session_dates.map(&:value).compact.sort.uniq

  def can_change_year_groups?
    school? && (new_record? || !open_for_consent?)
  end

  def set_notification_dates
    if earliest_date
      if generic_clinic?
        self.days_before_consent_reminders = nil
        self.send_consent_requests_at = nil
      else
        self.days_before_consent_reminders = team.days_before_consent_reminders
        self.send_consent_requests_at =
          earliest_date - team.days_before_consent_requests.days
      end
    else
      self.days_before_consent_reminders = nil
      self.send_consent_requests_at = nil
    end
  end

  def next_send_consent_requests_at
    return nil if send_consent_requests_at.nil?
    [send_consent_requests_at, Date.current].max
  end

  def read_from!(session)
    self.session_dates =
      session.dates.each_with_index.map do |value, index|
        DraftSessionDate.new(index:, value:)
      end

    session_dates << DraftSessionDate.new if session_dates.empty?

    super(session)
  end

  def write_to!(session)
    super(session)
    session.dates = dates.sort.uniq
  end

  def import_session_programme_year_groups!(session)
    rows =
      session_programme_year_groups.map do
        [session.id, it.programme_type, it.year_group]
      end

    ActiveRecord::Base.transaction do
      Session::ProgrammeYearGroup.where(session_id: session.id).delete_all
      Session::ProgrammeYearGroup.import!(
        %i[session_id programme_type year_group],
        rows,
        on_duplicate_key_ignore: true
      )
    end
  end

  def human_enum_name(attribute)
    Session.human_enum_name(attribute, send(attribute))
  end

  def supports_outbreak?
    programmes.any?(&:supports_outbreak?)
  end

  private

  def request_session_key = "session"

  def readable_attribute_names
    super - %w[dates return_to session_dates]
  end

  def writable_attribute_names
    super -
      %w[
        academic_year
        dates
        location_id
        programme_types
        return_to
        session_dates
        team_id
        year_groups
      ] + %w[team_location_id]
  end

  def include_notification_steps?
    dates.present? &&
      (
        session.nil? ||
          (
            session.consent_notifications.empty? &&
              session.session_notifications.empty?
          )
      )
  end

  def new_programme_types
    @new_programme_types ||= programme_types - (session&.programme_types || [])
  end

  def location_programme_year_groups
    @location_programme_year_groups ||=
      location.location_programme_year_groups.includes(:location_year_group)
  end

  def valid_session_dates
    session_dates.each_with_index do |session_date, index|
      value = session_date.value

      next if value.nil?

      if value < earliest_possible_session_date_value
        session_date.errors.add(
          :value,
          :greater_than_or_equal_to,
          count: earliest_possible_session_date_value
        )
      elsif value > latest_possible_session_date_value
        session_date.errors.add(
          :value,
          :less_than_or_equal_to,
          count: latest_possible_session_date_value
        )
      elsif session_dates[...index].any? { it.value == value }
        session_date.errors.add(:value, :taken)
      end
    end

    return if session_dates.all? { it.errors.empty? }

    session_dates.each_with_index do |session_date, index|
      session_date.errors.messages.each do |field, messages|
        messages.each do |message|
          errors.add("session-date-#{index}-#{field}", message)
        end
      end
    end
  end

  def cannot_remove_programmes
    if editing? && (session.programme_types - programme_types).present?
      errors.add(:programme_types, :inclusion)
    end
  end

  def valid_school_ids
    LocationPolicy::Scope
      .new(@current_user, Location)
      .resolve
      .gias_school
      .joins(:team_locations)
      .where(team_locations: { team:, academic_year: })
      .pluck(:"locations.id")
  end

  def earliest_date = dates.min

  def earliest_send_notifications_at
    earliest_date - 3.months
  end

  def latest_send_consent_requests_at
    earliest_date - days_before_consent_reminders.days - 1
  end

  def maximum_weeks_before_consent_reminders
    return nil if earliest_date.nil? || send_consent_requests_at.nil?
    (earliest_date - send_consent_requests_at).to_i / 7
  end

  def academic_year_date_range
    academic_year.to_academic_year_date_range
  end

  def earliest_possible_session_date_value
    academic_year_date_range.begin
  end

  def latest_possible_session_date_value
    academic_year_date_range.end
  end
end
