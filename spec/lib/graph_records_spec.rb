# frozen_string_literal: true

describe GraphRecords do
  subject(:graph) { described_class.new.graph(patient: patient.id) }

  around { |example| travel_to(Time.zone.local(2024, 2, 1)) { example.run } }

  let!(:programmes) { [Programme.hpv] }
  let!(:team) { create(:team, programmes:) }
  let!(:session) { create(:session, team:, programmes:) }
  let!(:class_import) { create(:class_import, session:) }
  let!(:cohort_import) { create(:cohort_import, team:) }
  let!(:parent) do
    create(
      :parent,
      class_imports: [class_import],
      cohort_imports: [cohort_import]
    )
  end
  let!(:patient) do
    create(
      :patient,
      parents: [parent],
      session:,
      team:,
      programmes:,
      class_imports: [class_import],
      cohort_imports: [cohort_import]
    )
  end
  let!(:consent) do
    create(
      :consent,
      :given,
      patient:,
      parent:,
      team:,
      programme: programmes.first
    )
  end

  def non_breaking_text(text)
    # Insert non-breaking spaces and hyphens to prevent Mermaid from breaking the line
    text.gsub(" ", "&nbsp;").gsub("-", "#8209;")
  end

  def wrap_in_detail_styling(text)
    # Wrap in the styling which is output for a line of detail on a model
    "<br><span style=\"font-size:14px\">#{non_breaking_text(text)}</span>"
  end

  it { should start_with "flowchart TB" }

  it "generates the graph" do
    # stree-ignore
    session_details =
      [
        "academic_year: #{session.academic_year}",
        "clinic?: #{session.clinic?}",
        "dates: #{session.dates}",
        "slug: #{session.slug}"
      ].map{wrap_in_detail_styling(it)}.join

    consent_details =
      [
        "created_at: 2024-02-01 00:00:00 +0000",
        "invalidated_at: ",
        "response: #{consent.response}",
        "route: #{consent.route}",
        "updated_at: 2024-02-01 00:00:00 +0000",
        "withdrawn_at: "
      ].map { wrap_in_detail_styling(it) }.join

    cohort_import_details =
      [
        "changed_record_count: ",
        "csv_filename: #{cohort_import.csv_filename}",
        "exact_duplicate_record_count: ",
        "new_record_count: ",
        "processed_at: ",
        "rows_count: #{cohort_import.rows_count}",
        "status: #{cohort_import.status}"
      ].map { wrap_in_detail_styling(it) }.join

    class_import_details =
      [
        "changed_record_count: ",
        "csv_filename: #{class_import.csv_filename}",
        "exact_duplicate_record_count: ",
        "new_record_count: ",
        "processed_at: ",
        "rows_count: #{class_import.rows_count}",
        "status: #{class_import.status}",
        "year_groups: #{class_import.year_groups}"
      ].map { wrap_in_detail_styling(it) }.join

    location_details =
      [
        "address_postcode: #{session.location.address_postcode}",
        "gias_year_groups: #{session.location.gias_year_groups}",
        "name: #{session.location.name}",
        "type: #{session.location.type}"
      ].map { wrap_in_detail_styling(it) }.join

    patient_location = patient.patient_locations.first

    expect(graph).to include(
      "flowchart TB",
      "  classDef patient_focused fill:#469990,color:white,stroke:#000,stroke-width:3px",
      "  classDef parent fill:#e6194B,color:white,stroke:#000",
      "  classDef consent fill:#aaffc3,color:black,stroke:#000",
      "  classDef cohort_import fill:#4363d8,color:white,stroke:#000",
      "  classDef class_import fill:#000075,color:white,stroke:#000",
      "  classDef session fill:#fabed4,color:black,stroke:#000",
      "  classDef location fill:#3cb44b,color:white,stroke:#000",
      "  classDef patient_location fill:#ffffff,color:black,stroke:#000",
      "  classDef programme fill:#3cb44b,color:white,stroke:#000",
      "  patient-#{patient.id}[\"Patient #{patient.id}<br><span style=\"font-size:10px\"><i>Patient.find(" \
        "#{patient.id})</i></span><br><span style=\"font-size:10px\"><i>puts&nbsp;GraphRecords.new.graph(patient:" \
        "&nbsp;#{patient.id})</i></span><br>" \
        "<span style=\"font-size:14px\">date_of_death_recorded_at:&nbsp;</span><br>" \
        "<span style=\"font-size:14px\">invalidated_at:&nbsp;</span><br><span style=\"font-size:14px\">" \
        "restricted_at:&nbsp;</span><br><span style=\"font-size:14px\">updated_from_pds_at:&nbsp;</span>\"]:::" \
        "patient_focused",
      "  parent-#{parent.id}[\"Parent #{parent.id}<br><span style=\"font-size:10px\"><i>Parent.find(#{parent.id})</i>" \
        "</span><br><span style=\"font-size:10px\"><i>puts&nbsp;GraphRecords.new.graph(parent:&nbsp;#{parent.id})</i>" \
        "</span>\"]:::parent",
      "  consent-#{consent.id}[\"Consent #{consent.id}<br><span style=\"font-size:10px\"><i>Consent.find(" \
        "#{consent.id})</i></span><br><span style=\"font-size:10px\"><i>puts&nbsp;GraphRecords.new.graph(consent:" \
        "&nbsp;#{consent.id})</i></span>#{consent_details}\"]:::consent",
      "  cohort_import-#{cohort_import.id}[\"Cohort import #{cohort_import.id}<br><span style=\"font-size:10px\"><i>" \
        "CohortImport.find(#{cohort_import.id})</i></span><br><span style=\"font-size:10px\"><i>puts&nbsp;" \
        "GraphRecords.new.graph(cohort_import:&nbsp;#{cohort_import.id})</i></span>#{cohort_import_details}\"]:::" \
        "cohort_import",
      "  class_import-#{class_import.id}[\"Class import #{class_import.id}<br><span style=\"font-size:10px\"><i>" \
        "ClassImport.find(#{class_import.id})</i></span><br><span style=\"font-size:10px\"><i>puts&nbsp;GraphRecords." \
        "new.graph(class_import:&nbsp;#{class_import.id})</i></span>#{class_import_details}\"]:::class_import",
      "  session-#{session.id}[\"Session #{session.id}<br><span style=\"font-size:10px\"><i>Session.find(" \
        "#{session.id})</i></span><br><span style=\"font-size:10px\"><i>puts&nbsp;GraphRecords.new.graph(session:" \
        "&nbsp;#{session.id})</i></span>#{session_details}\"]:::session",
      "  location-#{session.location.id}[\"Location #{session.location.id}<br><span style=\"font-size:10px\"><i>" \
        "Location.find(#{session.location.id})</i></span><br><span style=\"font-size:10px\"><i>puts&nbsp;GraphRecords" \
        ".new.graph(location:&nbsp;#{session.location.id})</i></span>#{location_details}\"]:::location",
      "  patient-#{patient.id} --> parent-#{parent.id}",
      "  consent-#{consent.id} --> parent-#{parent.id}",
      "  patient-#{patient.id} --> consent-#{consent.id}",
      "  patient_location-#{patient_location&.id} --> patient-#{patient.id}",
      "  cohort_import-#{cohort_import.id} --> parent-#{parent.id}",
      "  class_import-#{class_import.id} --> parent-#{parent.id}",
      "  cohort_import-#{cohort_import.id} --> patient-#{patient.id}",
      "  class_import-#{class_import.id} --> patient-#{patient.id}",
      "  location-#{session.location.id} --> session-#{session.id}",
      "  location-#{session.location.id} --> patient-#{patient.id}",
      "  location-#{patient.school.id} --> patient_location-#{patient_location&.id}"
    )
  end

  context "when node limit is exceeded" do
    subject(:graph_exceeded) do
      described_class.new(
        node_limit: 1 # A very low limit to trigger recursion limit early
      ).graph(patients: [patient])
    end

    it "returns a fallback Mermaid diagram with the error message in a red box" do
      error_message =
        "Recursion limit of 1 nodes has been exceeded. Try restricting the graph."
      expect(graph_exceeded).to include("flowchart TB")
      # Assuming the error node is named `error` we check its content.
      expect(graph_exceeded.join).to include("error[#{error_message}]")
      expect(graph_exceeded.join).to include(
        "style error fill:#f88,stroke:#f00,stroke-width:2px"
      )
    end
  end
end
