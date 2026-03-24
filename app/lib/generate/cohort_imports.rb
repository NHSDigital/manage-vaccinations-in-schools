# frozen_string_literal: true

require "csv"

Faker::Config.locale = "en-GB"

class Generate::CohortImports
  def initialize(
    team:,
    programmes: nil,
    urns: nil,
    school_year_groups: nil,
    patient_count: 10,
    progress_bar: nil
  )
    @team = team
    @programmes = programmes.presence || team.programmes
    @urns = urns || @team.gias_schools.pluck(:urn)
    @school_year_groups = school_year_groups
    @patient_count = patient_count
    @progress_bar = progress_bar
    @nhs_numbers = Set.new
  end

  def self.call(...) = new(...).call

  def call = write_cohort_import_csv

  def patients
    patient_count.times.lazy.map { build_patient }
  end

  private

  attr_reader :team,
              :programmes,
              :urns,
              :patient_count,
              :school_year_groups,
              :progress_bar

  def academic_year = AcademicYear.current

  def all_year_groups
    programmes.flat_map(&:default_year_groups).uniq
  end

  def cohort_import_csv_filepath
    @cohort_import_csv_filepath ||=
      begin
        timestamp = Time.current.strftime("%Y%m%d%H%M%S")
        size =
          ActiveSupport::NumberHelper.number_to_human(
            @patient_count,
            units: {
              thousand: "k",
              million: "m"
            },
            format: "%n%u"
          )
        Rails.root.join(
          "tmp/cohort-import-" \
            "#{team.workgroup}-#{programmes.map(&:type).join("-")}-#{size}-#{timestamp}.csv"
        )
      end
  end

  def write_cohort_import_csv
    CSV.open(cohort_import_csv_filepath, "w") do |csv|
      csv << %w[
        CHILD_ADDRESS_LINE_1
        CHILD_ADDRESS_LINE_2
        CHILD_POSTCODE
        CHILD_TOWN
        CHILD_PREFERRED_GIVEN_NAME
        CHILD_DATE_OF_BIRTH
        CHILD_FIRST_NAME
        CHILD_LAST_NAME
        CHILD_NHS_NUMBER
        PARENT_1_EMAIL
        PARENT_1_NAME
        PARENT_1_PHONE
        PARENT_1_RELATIONSHIP
        PARENT_2_EMAIL
        PARENT_2_NAME
        PARENT_2_PHONE
        PARENT_2_RELATIONSHIP
        CHILD_SCHOOL_URN
      ]

      patients.each do |patient|
        csv << [
          patient.address_line_1,
          patient.address_line_2,
          patient.address_postcode,
          patient.address_town,
          patient.preferred_given_name,
          patient.date_of_birth,
          patient.given_name,
          patient.family_name,
          patient.nhs_number,
          patient.parents.first&.email,
          patient.parents.first&.full_name,
          patient.parents.first&.phone,
          patient.parent_relationships.first&.type,
          patient.parents.second&.email,
          patient.parents.second&.full_name,
          patient.parents.second&.phone,
          patient.parent_relationships.second&.type,
          patient.school.urn
        ]
        progress_bar&.increment
      end
    end

    cohort_import_csv_filepath.to_s
  end

  def schools_with_year_groups
    @schools_with_year_groups ||=
      begin
        locations =
          if school_year_groups.present?
            urns.map do |urn|
              Location.new(urn:, year_groups: school_year_groups[urn])
            end
          else
            team.locations.where(urn: urns).includes(:sessions)
          end

        locations.select { (it.gias_year_groups & all_year_groups).any? }
      end
  end

  def build_patient
    school = schools_with_year_groups.sample
    year_group ||= (school.gias_year_groups & all_year_groups).sample
    nhs_number = nil
    loop do
      nhs_number = Faker::NationalHealthService.british_number.gsub(" ", "")
      break unless nhs_number.in? @nhs_numbers
    end
    @nhs_numbers << nhs_number

    FactoryBot
      .build(
        :patient,
        school:,
        team:,
        date_of_birth: date_of_birth_for_year(year_group),
        nhs_number:
      )
      .tap do |patient|
        patient.parents =
          FactoryBot.build_list(:parent, 2, family_name: patient.family_name)
        patient.parent_relationships =
          patient.parents.map do
            FactoryBot.build(:parent_relationship, parent: it, patient:)
          end
      end
  end

  def date_of_birth_for_year(year_group)
    rand(
      year_group.to_birth_academic_year(
        academic_year:
      ).to_academic_year_date_range
    )
  end
end
