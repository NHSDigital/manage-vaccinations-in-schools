# frozen_string_literal: true

class SessionSearchForm < SearchForm
  attribute :academic_year, :integer
  attribute :programmes, array: true
  attribute :query, :string
  attribute :status, :string
  attribute :type, :string

  def academic_year = super || AcademicYear.pending

  def programmes=(values)
    super(values&.compact_blank || [])
  end

  def apply(scope)
    scope = filter_academic_year(scope)
    scope = filter_programmes(scope)
    scope = filter_name(scope)
    scope = filter_type(scope)
    scope = filter_status(scope)

    scope.order_by_earliest_date
  end

  private

  def filter_academic_year(scope)
    scope.for_academic_year(academic_year)
  end

  def filter_programmes(scope)
    programmes.present? ? scope.has_all_programme_types_of(programmes) : scope
  end

  def filter_name(scope)
    query.present? ? scope.search_by_name(query) : scope
  end

  def filter_type(scope)
    type.present? ? scope.joins(:location).where(locations: { type: }) : scope
  end

  def filter_status(scope)
    status.in?(VALID_STATUS_SCOPES) ? scope.public_send(status) : scope
  end

  VALID_STATUS_SCOPES = %w[in_progress unscheduled scheduled completed].freeze
end
