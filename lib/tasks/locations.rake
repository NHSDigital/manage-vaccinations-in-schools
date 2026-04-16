# frozen_string_literal: true

namespace :locations do
  desc "Import default programme year groups for all schools and clinics managed by a team."
  task import_default_programme_year_groups: :environment do
    programmes = Programme.all
    academic_year = AcademicYear.current

    Location
      .where(type: %w[generic_clinic generic_school gias_school])
      .with_team(academic_year:)
      .find_each do |location|
        location.import_default_programme_year_groups!(
          programmes,
          academic_year:
        )
      end
  end
end
