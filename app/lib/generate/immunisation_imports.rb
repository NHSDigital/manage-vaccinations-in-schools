# frozen_string_literal: true

require "csv"

Faker::Config.locale = "en-GB"

class Generate::ImmunisationImports
  def initialize(team:, programmes: nil, count: 10, progress_bar: nil)
    @team = team
    @programmes = programmes.presence || team.programmes
    @count = count
    @progress_bar = progress_bar

    # validate_programmes
  end

  def self.call(...) = new(...).call

  def call = write_immunisation_import_csv

  def vaccination_records
    count.times.lazy.map { build_vaccination_record }
  end

  private

  attr_reader :team,
              :programmes,
              :urns,
              :count,
              :school_year_groups,
              :progress_bar

  def immunisation_import_csv_filepath
    @immunisation_import_csv_filepath ||=
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
          "tmp/immunisation-import-" \
            "#{team.workgroup}-#{programmes.map(&:type).join("-")}-#{size}-#{timestamp}.csv"
        )
      end
  end

  def write_immunisation_import_csv
    CSV.open(immunisation_import_csv_filepath, "w") do |csv|
      csv << %w[
        ORGANISATION_CODE
        SCHOOL_URN
        SCHOOL_NAME
        NHS_NUMBER
        PERSON_FORENAME
        PERSON_SURNAME
        PERSON_DOB
        PERSON_GENDER_CODE
        PERSON_POSTCODE
        VACCINATED
        DATE_OF_VACCINATION
        PROGRAMME
        VACCINE_GIVEN
        BATCH_NUMBER
        BATCH_EXPIRY_DATE
        ANATOMICAL_SITE
        PERFORMING_PROFESSIONAL_FORENAME
        PERFORMING_PROFESSIONAL_SURNAME
        REASON_NOT_VACCINATED
        CONSENT_TYPE
        LOCAL_PATIENT_ID
        LOCAL_PATIENT_ID_URI
      ]

      vaccination_records.each do |vaccination_record|
        patient = vaccination_record.patient
        user = team.users.sample
        csv << [
          team.organisation.ods_code,
          vaccination_record.location.urn,
          vaccination_record.location.name,
          patient.nhs_number,
          patient.given_name,
          patient.family_name,
          patient.date_of_birth,
          patient.gender_code,
          patient.address_postcode,
          "Yes",
          vaccination_record.performed_at,
          programme_type(vaccination_record.programme),
          vaccination_record.vaccine.upload_name,
          vaccination_record.batch_number,
          vaccination_record.batch_expiry,
          delivery_site(vaccination_record.delivery_site),
          user.given_name,
          user.family_name,
          "",
          "Parental consent",
          SecureRandom.uuid,
          "generated.test.manage-vaccinations-in-schools.nhs.uk"
        ]
        progress_bar&.increment
      end
    end

    immunisation_import_csv_filepath.to_s
  end

  def build_vaccination_record
    programme = team.programmes.sample
    vaccine = vaccine_roulette(programme)

    FactoryBot.build(
      :vaccination_record,
      location: team.locations.sample,
      programme:,
      vaccine:,
      team:
    )
  end

  def vaccine_roulette(programme)
    @vaccines_cache ||= {}
    @vaccines_cache[programme.type] ||= []

    if @vaccines_cache[programme.type].empty? || rand < 0.2
      programme.vaccines.sample.tap { @vaccines_cache[programme.type] << it }
    else
      @vaccines_cache[programme.type].sample
    end
  end

  def delivery_site(anatomical_site)
    ImmunisationImportRow::DELIVERY_SITES.invert[anatomical_site]
  end

  def programme_type(programme)
    { "hpv" => "HPV", "menacwy" => "MenACWY", "tpd_ipv" => "Td/IPV" }[
      programme.type
    ] || programme.type.titleize
  end
end
