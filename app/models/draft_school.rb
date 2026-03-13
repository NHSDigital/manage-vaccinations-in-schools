# frozen_string_literal: true

class DraftSchool
  include RequestSessionPersistable
  include EditableWrapper
  include WizardStepConcern

  attribute :parent_urn_and_site, :string
  attribute :urn, :string
  attribute :confirm_school, :string
  attribute :name, :string
  attribute :address_line_1, :string
  attribute :address_line_2, :string
  attribute :address_town, :string
  attribute :address_postcode, :string
  attribute :selected_year_groups, default: []
  attribute :context, :string

  attr_reader :current_team

  def initialize(
    request_session:,
    current_user:,
    current_team: nil,
    **attributes
  )
    @current_user = current_user
    @current_team = current_team
    super(request_session:, **attributes)
  end

  def name=(value)
    super(ApostropheNormaliser.call(value.presence&.normalise_whitespace))
  end

  def address_line_1=(value)
    super(ApostropheNormaliser.call(value.presence&.normalise_whitespace))
  end

  def address_line_2=(value)
    super(ApostropheNormaliser.call(value.presence&.normalise_whitespace))
  end

  def address_town=(value)
    super(ApostropheNormaliser.call(value.presence&.normalise_whitespace))
  end

  def wizard_steps
    [
      (:school if add_site_context? && !editing?),
      (:details if add_site_context? || editing?),
      (:urn if add_school_context?),
      (:confirm_urn if add_school_context?),
      :year_groups,
      :confirm
    ].compact
  end

  def add_school_context?
    context == "add_school"
  end

  def add_site_context?
    context == "add_site"
  end

  on_wizard_step :urn, exact: true do
    validates :urn, presence: true
    validate :school_exists_and_available
  end

  on_wizard_step :confirm_urn, exact: true do
    validates :confirm_school, inclusion: { in: %w[yes no] }
  end

  on_wizard_step :school, exact: true do
    validates :parent_urn_and_site, presence: true
  end

  on_wizard_step :details, exact: true do
    validates :name,
              presence: true,
              name: {
                school_name: true
              },
              exclusion: {
                in: ->(record) { record.existing_names },
                message:
                  "This site name is already in use. Enter a different name."
              }
    validates :address_line_1, presence: true
    validates :address_town, presence: true
    validates :address_postcode, postcode: true
  end

  on_wizard_step :year_groups, exact: true do
    validates :selected_year_groups, presence: true
    validate :cannot_remove_year_groups
  end

  # Returns the source location based on context:
  # - When editing: the location being edited
  # - When adding school: the school found by URN
  # - When adding site: the parent school to add a site to
  def source_location
    return Location.find(editing_id) if editing?
    return nil if add_site_context? && parent_urn_and_site.blank?
    return nil if add_school_context? && urn.blank?

    if add_school_context?
      Location.find_by_urn_and_site(urn.strip)
    else
      LocationPolicy::Scope
        .new(@current_user, Location)
        .resolve
        .find_by_urn_and_site(parent_urn_and_site)
    end
  end

  def existing_names
    return [] if resolved_urn.blank?

    scope = schools_with_urn
    scope = scope.where.not(id: editing_id) if editing?
    scope.pluck(:name)
  end

  def request_session_key = "draft_school"

  def address_parts
    [
      address_line_1,
      address_line_2,
      address_town,
      address_postcode
    ].compact_blank
  end

  def readable_attribute_names
    writable_attribute_names
  end

  def writable_attribute_names
    %w[name address_line_1 address_line_2 address_town address_postcode]
  end

  def resolved_urn
    source_location&.urn
  end

  def urn_and_site
    if editing?
      source_location&.urn_and_site
    else
      return nil if resolved_urn.blank?

      add_school_context? ? resolved_urn : "#{resolved_urn}#{next_site_letter}"
    end
  end

  def next_site_letter
    return nil if resolved_urn.blank?

    existing_sites = schools_with_urn.pluck(:site).compact.sort
    return "B" if existing_sites.empty?

    existing_sites.max_by { [it.length, it] }.next
  end

  def existing_year_groups
    source_location&.year_groups.presence ||
      source_location&.gias_year_groups || []
  end

  def year_groups
    selected_year_groups.presence || existing_year_groups
  end

  def year_groups=(values)
    self.selected_year_groups = values&.compact_blank&.map(&:to_i) || []
  end

  def programmes
    return source_location.programmes if source_location&.programmes.present?
    return [] if current_team.nil?

    current_team.programmes.select do |programme|
      (programme.default_year_groups & year_groups).any?
    end
  end

  def human_enum_name(attr)
    source_location&.human_enum_name(attr)
  end

  def schools_with_urn
    return [] if resolved_urn.blank?

    Location.where(urn: resolved_urn)
  end

  private

  def cannot_remove_year_groups
    return unless editing?
    return if selected_year_groups.blank?

    if (source_location.year_groups - selected_year_groups).present?
      errors.add(:selected_year_groups, :inclusion)
    end
  end

  def school_exists_and_available
    return if urn.blank?

    if source_location.nil?
      errors.add(:urn, "No school found with this URN")
      return
    end

    if source_location.closed?
      errors.add(
        :urn,
        "This school is closed and cannot be added to your team."
      )
      return
    end

    sites =
      Location
        .where(id: schools_with_urn.map(&:id))
        .joins(:team_locations)
        .where(team_locations: { academic_year: AcademicYear.pending })

    if sites.where(team_locations: { team: current_team }).exists?
      errors.add(:urn, "This school has already been added to your team.")
      return
    end

    if sites.where.not(team_locations: { team: current_team }).exists?
      errors.add(
        :urn,
        "This school is already assigned to another team. Contact the Mavis team if this needs to be changed."
      )
    end
  end
end
