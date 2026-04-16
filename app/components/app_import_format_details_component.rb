# frozen_string_literal: true

class AppImportFormatDetailsComponent < ViewComponent::Base
  def initialize(import:)
    @import = import
  end

  private

  delegate :team, to: :@import
  delegate :govuk_details, :govuk_table, to: :helpers

  def columns
    case @import
    when ClassImport
      class_import_columns
    when CohortImport
      cohort_import_columns
    when ImmunisationImport
      immunisation_import_columns
    end
  end

  def class_import_columns
    child_columns +
      [
        {
          name: "CHILD_POSTCODE",
          notes:
            "Optional, must be a full postcode, for example #{tag.i("SW1A 1AA")}"
        }
      ] + parent_columns
  end

  def cohort_import_columns
    child_columns +
      [
        {
          name: "CHILD_POSTCODE",
          notes:
            "#{tag.strong("Required")}, must be a full postcode, for example #{tag.i("SW1A 1AA")}"
        },
        {
          name: "CHILD_SCHOOL_URN",
          notes:
            "#{tag.strong("Required")}, must be 6 digits and numeric. " \
              "Use #{tag.i("888888")} for school unknown and #{tag.i("999999")} " \
              "for homeschooled."
        }
      ] + parent_columns
  end

  def immunisation_import_columns
    if team.has_national_reporting_access?
      national_reporting_immunisation_import_columns
    else
      point_of_care_immunisation_import_columns
    end
  end

  def point_of_care_immunisation_import_columns
    organisation_code(optionality: "Optional") +
      school_urn(optionality: "Optional") + school_name + nhs_number +
      patient_demographics + date_and_time_of_vaccination +
      vaccinated(
        notes:
          "Enter #{tag.i("Y")} or #{tag.i("N")}. Mavis will assume #{tag.i("Y")} if " \
            "#{tag.code(" VACCINE_GIVEN ")} is provided."
      ) + vaccine_and_batch + programme + anatomical_site +
      reason_not_vaccinated_and_notes + dose_sequence + care_setting +
      performing_professional
  end

  def national_reporting_immunisation_import_columns
    organisation_code(optionality: "Required") +
      school_urn(optionality: "Required") + nhs_number +
      patient_demographics(gender_field_name: "PERSON_GENDER") +
      vaccinated(
        notes:
          "Optional, enter #{tag.i("Y")} or #{tag.i("N")}. If you enter nothing, Mavis will assume " \
            "#{tag.i("Y")}. If you enter #{tag.i("N")}, the row will not be uploaded."
      ) + date_and_time_of_vaccination + national_reporting_vaccine_and_batch +
      national_reporting_anatomical_site + national_reporting_dose_sequence +
      national_reporting_performing_professional_names + local_patient_id
  end

  def child_columns
    [
      {
        name: "CHILD_FIRST_NAME",
        notes:
          "#{tag.strong("Required")}, must use alphabetical characters (you" \
            " can include accents like Chloë, hyphens like Anne-Marie or" \
            " apostrophes like D'Arcy but no other special characters)."
      },
      {
        name: "CHILD_LAST_NAME",
        notes:
          "#{tag.strong("Required")}, must use alphabetical characters (you" \
            " can include accents like Jiménez, hyphens like Burne-Jones or" \
            " apostrophes like O'Hare but no other special characters)."
      },
      {
        name: "CHILD_PREFERRED_FIRST_NAME",
        notes:
          "Optional, must use alphabetical characters (you can include" \
            " accents like Chloë, hyphens like Anne-Marie or apostrophes like" \
            " D'Arcy but no other special characters)."
      },
      {
        name: "CHILD_PREFERRED_LAST_NAME",
        notes:
          "Optional, must use alphabetical characters (you can include" \
            " accents like Jiménez, hyphens like Burne-Jones or apostrophes" \
            " like O'Hare but no other special characters)."
      },
      {
        name: "CHILD_DATE_OF_BIRTH",
        notes:
          "#{tag.strong("Required")}, must use #{tag.i("DD/MM/YYYY")} or #{tag.i("YYYY-MM-DD")} format."
      },
      {
        name: "CHILD_YEAR_GROUP",
        notes:
          "Optional, numeric, for example #{tag.i("8")}. If present, and " \
            "when the child’s date of birth would place them in a different year, this value can " \
            "be used to override the cohort the child will be placed in."
      },
      {
        name: "CHILD_REGISTRATION",
        notes:
          "Optional, the child’s registration group, for example #{tag.i("8T5")}."
      },
      {
        name: "CHILD_NHS_NUMBER",
        notes: "You must enter a valid NHS number if available."
      },
      {
        name: "CHILD_GENDER",
        notes:
          "Optional, must be one of: #{tag.i("female")}, #{tag.i("male")}, " \
            "#{tag.i("not known")} or #{tag.i("not specified")}."
      },
      { name: "CHILD_ADDRESS_LINE_1", notes: "Optional" },
      { name: "CHILD_ADDRESS_LINE_2", notes: "Optional" },
      { name: "CHILD_TOWN", notes: "Optional" }
    ]
  end

  def organisation_code(optionality:)
    [
      {
        name: "ORGANISATION_CODE",
        notes:
          "#{tag.strong(optionality)}, must be a valid #{link_to("ODS code", "https://www.odsdatasearchandexport.nhs.uk/")}."
      }
    ]
  end

  def nhs_number
    [
      {
        name: "NHS_NUMBER",
        notes:
          "You must enter a valid #{
            link_to(
              "NHS number",
              "https://www.datadictionary.nhs.uk/attributes/nhs_number.html"
            )
          } if available."
      }
    ]
  end

  def school_urn(optionality:)
    [
      {
        name: "SCHOOL_URN",
        notes:
          "#{tag.strong(optionality)}, must be 6 digits and numeric. " \
            "Use #{tag.i("888888")} for school unknown and #{tag.i("999999")} " \
            "for homeschooled."
      }
    ]
  end

  def school_name
    [
      {
        name: "SCHOOL_NAME",
        notes: "Required if #{tag.code("SCHOOL_URN")} is #{tag.i("888888")}."
      }
    ]
  end

  def patient_demographics(gender_field_name: "PERSON_GENDER_CODE")
    [
      {
        name: "PERSON_FORENAME",
        notes:
          "#{tag.strong("Required")}, must use alphabetical characters " \
            "(you can include accents like Chloë, hyphens like Anne-Marie or apostrophes like D'Arcy " \
            "but no other special characters)."
      },
      {
        name: "PERSON_SURNAME",
        notes:
          "#{tag.strong("Required")}, must use alphabetical characters " \
            "(you can include accents like Jiménez, hyphens like Burne-Jones or apostrophes like O'Hare " \
            "but no other special characters)."
      },
      {
        name: "PERSON_DOB",
        notes:
          "#{tag.strong("Required")}, you must use either #{tag.i("YYYYMMDD")} or " \
            "#{tag.i("DD/MM/YYYY")} format."
      },
      {
        name: gender_field_name,
        notes:
          "#{tag.strong("Required")}, must be one of: #{tag.i("female")}, " \
            "#{tag.i("male")}, #{tag.i("not known")} or #{tag.i("not specified")}."
      },
      {
        name: "PERSON_POSTCODE",
        notes:
          "#{tag.strong("Required")}, must be a full postcode, for example #{tag.i("SW1A 1AA")}"
      }
    ]
  end

  def vaccinated(notes:)
    [{ name: "VACCINATED", notes: }]
  end

  def date_and_time_of_vaccination
    [
      {
        name: "DATE_OF_VACCINATION",
        notes:
          "#{tag.strong("Required")}, you must use either #{tag.i("YYYYMMDD")} or #{tag.i("DD/MM/YYYY")} format."
      },
      {
        name: "TIME_OF_VACCINATION",
        notes: "Optional, use #{tag.i("HH:MM:SS")} format."
      }
    ]
  end

  def parent_columns
    %w[PARENT_1 PARENT_2].flat_map do |prefix|
      [
        {
          name: "#{prefix}_NAME",
          notes:
            "Optional, must use alphabetical characters (you can include" \
              " accents like Chloë, hyphens like Anne-Marie or apostrophes" \
              " like D'Arcy but no other special characters)."
        },
        {
          name: "#{prefix}_RELATIONSHIP",
          notes:
            "Optional, must be one of: #{tag.i("Mum")}, #{tag.i("Dad")} or " \
              "#{tag.i("Guardian")}."
        },
        {
          name: "#{prefix}_EMAIL",
          notes: "Optional, must be formatted as a valid email address."
        },
        {
          name: "#{prefix}_PHONE",
          notes: "Optional, must be formatted as a valid phone number."
        }
      ]
    end
  end

  def programme
    programmes = team.programmes.flat_map(&:import_names).map { tag.i(it) }
    programmes_sentence = to_sentence_with_or(programmes)

    [
      {
        name: "PROGRAMME",
        notes: "#{tag.strong("Required")}, must be #{programmes_sentence}."
      }
    ]
  end

  def vaccine_and_batch
    vaccines = team.vaccines.pluck(:upload_name).map { tag.i(it) }

    [
      {
        name: "VACCINE_GIVEN",
        notes: "Optional, must be one of: #{to_sentence_with_or(vaccines)}."
      },
      { name: "BATCH_NUMBER", notes: "Optional" },
      {
        name: "BATCH_EXPIRY_DATE",
        notes:
          "Optional, use either #{tag.i("YYYYMMDD")} or #{tag.i("DD/MM/YYYY")} format."
      }
    ]
  end

  def national_reporting_vaccine_and_batch
    vaccine_given_notes_per_programme =
      [Programme.hpv, Programme.flu].map do |programme|
        vaccines =
          programme
            .vaccines
            .where.not(nivs_name: [nil, ""])
            .order(:nivs_name)
            .pluck(:nivs_name)
            .map { tag.i(it) }

        "#{tag.br}#{tag.br}" \
          "For #{programme.name_in_sentence} records, must be one of: " \
          "#{to_sentence_with_or(vaccines)}."
      end

    [
      {
        name: "VACCINE_GIVEN",
        notes:
          ([tag.strong("Required")] + vaccine_given_notes_per_programme).join
      },
      { name: "BATCH_NUMBER", notes: tag.strong("Required") },
      {
        name: "BATCH_EXPIRY_DATE",
        notes:
          "#{tag.strong("Required")}, must use #{tag.i("YYYYMMDD")} format."
      }
    ]
  end

  def anatomical_site
    sites = ImmunisationImportRow::DELIVERY_SITES.keys.sort.map { tag.i(_1) }

    site_sentence =
      sites.to_sentence(
        last_word_connector: " or ",
        two_words_connector: " or "
      )

    [
      {
        name: "ANATOMICAL_SITE",
        notes:
          "Optional, if provided must be appropriate for the vaccine delivery method " \
            "and be one of: #{site_sentence}."
      }
    ]
  end

  def reason_not_vaccinated_and_notes
    reasons =
      ImmunisationImportRow::REASONS_NOT_ADMINISTERED.keys.sort.map do
        tag.i(it)
      end
    reasons_sentence =
      reasons.to_sentence(
        last_word_connector: " or ",
        two_words_connector: " or "
      )

    [
      {
        name: "REASON_NOT_VACCINATED",
        notes:
          "Required if #{tag.code("VACCINATED")} is #{tag.i("N")}, must be #{reasons_sentence}."
      },
      { name: "NOTES", notes: "Optional" }
    ]
  end

  def dose_sequence
    special_values =
      ImmunisationImportRow::DOSE_SEQUENCES
        .values
        .flat_map(&:keys)
        .sort
        .uniq
        .map { tag.i(it) }

    special_values_sentence =
      special_values.to_sentence(
        last_word_connector: " or ",
        two_words_connector: " or "
      )

    [
      {
        name: "DOSE_SEQUENCE",
        notes: "Optional, must be a number or #{special_values_sentence}."
      }
    ]
  end

  def care_setting
    [
      {
        name: "CARE_SETTING",
        notes:
          "Optional, must be #{tag.i("1")} (school) or #{tag.i("2")} (clinic)."
      },
      {
        name: "CLINIC_NAME",
        notes:
          "Required if #{tag.code("CARE_SETTING")} is #{tag.i("2")}, must be " \
            "the name of a community clinic location."
      }
    ]
  end

  def performing_professional
    [
      {
        name: "PERFORMING_PROFESSIONAL_EMAIL",
        notes: "Required if uploading offline vaccination records."
      },
      { name: "PERFORMING_PROFESSIONAL_FORENAME", notes: "Optional" },
      { name: "PERFORMING_PROFESSIONAL_SURNAME", notes: "Optional" }
    ]
  end

  def national_reporting_performing_professional_names
    [
      {
        name: "PERFORMING_PROFESSIONAL_FORENAME",
        notes: "Required for flu records, optional for HPV records."
      },
      {
        name: "PERFORMING_PROFESSIONAL_SURNAME",
        notes: "Required for flu records, optional for HPV records."
      }
    ]
  end

  def supplier
    [
      {
        name: "SUPPLIER_EMAIL",
        notes: "Required if uploading delegated vaccination records."
      }
    ]
  end

  def national_reporting_anatomical_site
    sites = ImmunisationImportRow::DELIVERY_SITES.keys.sort.map { tag.i(it) }

    site_sentence =
      sites.to_sentence(
        last_word_connector: " or ",
        two_words_connector: " or "
      )

    [
      {
        name: "ANATOMICAL_SITE",
        notes: "#{tag.strong("Required")}, must be one of: #{site_sentence}."
      }
    ]
  end

  def national_reporting_dose_sequence
    hpv_max = Programme.hpv.maximum_dose_sequence
    flu_max = Programme.flu.maximum_dose_sequence

    [
      {
        name: "DOSE_SEQUENCE",
        notes:
          "Required for HPV records, optional for flu records." \
            "#{tag.br} #{tag.br}" \
            "Must be a number between 1 and #{hpv_max} for HPV records and between 1 and #{flu_max} for flu records."
      }
    ]
  end

  def local_patient_id
    [
      {
        name: "LOCAL_PATIENT_ID",
        notes:
          "#{tag.strong("Required")}, supplied automatically by your vaccination recording system."
      },
      {
        name: "LOCAL_PATIENT_ID_URI",
        notes:
          "#{tag.strong("Required")}, supplied automatically by your vaccination recording system."
      }
    ]
  end

  def to_sentence_with_or(items)
    items.to_sentence(last_word_connector: " or ", two_words_connector: " or ")
  end
end
