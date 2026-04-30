# frozen_string_literal: true

describe AppActivityLogComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(patient:, session:, team:) }

  let(:today) { Date.new(2026, 1, 1) }

  let(:programmes) { [Programme.hpv, Programme.flu, Programme.mmr] }
  let(:team) { create(:team, programmes:) }
  let(:user) { create(:user, team:, family_name: "Joy", given_name: "Nurse") }
  let(:location) do
    create(:gias_school, :secondary, name: "Hogwarts", programmes:)
  end
  let(:session) { create(:session, programmes:, location:) }
  let(:session_last_year) do
    create(:session, programmes:, location:, date: 1.year.ago.to_date)
  end
  let(:patient) do
    create(
      :patient,
      school: location,
      given_name: "Sarah",
      family_name: "Doe",
      nhs_number: "9999075320",
      date_of_birth: Date.new(2010, 1, 1),
      year_group: 9
    )
  end

  let(:mum) { create(:parent, full_name: "Jane Doe") }
  let(:dad) { create(:parent, full_name: "John Doe") }

  before do
    travel_to Date.new(2026, 1, 1)

    create(:parent_relationship, :mother, parent: mum, patient:)
    create(:parent_relationship, :father, parent: dad, patient:)

    patient
      .patient_locations
      .find_by(location_id: session.location_id)
      &.update!(created_at: Time.zone.local(2025, 5, 29, 12))

    patient.reload
  end

  shared_examples "card" do |title:, date:, notes: nil, by: nil, index: nil, programme: nil|
    it "renders card '#{title}'" do
      expect(rendered).to have_css(".app-timeline__header", text: title)

      card =
        if index
          page.all(".app-timeline__item")[index]
        elsif programme
          page
            .all(".app-timeline__item")
            .find do |card_element|
              card_element.has_css?(".app-timeline__header", text: title) &&
                card_element.has_css?(
                  "p.app-timeline__description",
                  text: programme
                )
            end
        else
          page.find(".app-timeline__header", text: title).ancestor(
            ".app-timeline__item"
          )
        end

      expect(card).to have_css("p.app-timeline__description", text: date)
      expect(card).to have_css("p.app-timeline__description", text: by) if by
      expect(card).to have_css("blockquote", text: notes) if notes
    end
  end

  describe "archive reasons" do
    let(:component) { described_class.new(patient:, team:) }

    before do
      create(
        :archive_reason,
        :other,
        created_at: Time.zone.local(2024, 6, 1, 12),
        created_by: user,
        team:,
        other_details: "Extra details",
        patient:
      )
    end

    include_examples "card",
                     title: "Record archived: Other",
                     notes: "Extra details",
                     date: "1 June 2024 at 12:00pm",
                     by: "JOY, Nurse"
  end

  describe "consent given by parents" do
    before do
      create(
        :consent,
        :given,
        programme: programmes.first,
        patient:,
        parent: mum,
        submitted_at: Time.zone.local(2025, 5, 30, 12),
        recorded_by: user
      )
      create(
        :consent,
        :refused,
        programme: programmes.first,
        patient:,
        parent: dad,
        submitted_at: Time.zone.local(2025, 5, 30, 13)
      )
      create(
        :consent,
        :given,
        programme: programmes.second,
        patient:,
        parent: dad,
        submitted_at: Time.zone.local(2025, 5, 30, 13),
        vaccine_methods: ["nasal"]
      )

      create(
        :triage,
        :keep_in_triage,
        programme: programmes.first,
        patient:,
        created_at: Time.zone.local(2025, 5, 30, 14),
        notes: "Some notes",
        performed_by: user
      )
      create(
        :triage,
        :safe_to_vaccinate,
        programme: programmes.first,
        patient:,
        created_at: Time.zone.local(2025, 5, 30, 14, 30),
        performed_by: user
      )
      create(
        :triage,
        :safe_to_vaccinate,
        programme: programmes.second,
        patient:,
        created_at: Time.zone.local(2025, 5, 30, 14, 35),
        notes: "Some notes",
        performed_by: user,
        vaccine_method: "nasal"
      )

      create(
        :vaccination_record,
        programme: programmes.first,
        patient:,
        session:,
        performed_at: Time.zone.local(2025, 5, 31, 12, 0, 0, 0),
        performed_by: user,
        notes: "Some notes"
      )

      create(
        :vaccination_record,
        programme: programmes.first,
        patient:,
        session:,
        performed_at: Time.zone.local(2025, 5, 31, 12, 0, 0, 1),
        performed_by: nil,
        notes: "Some notes millisecond later",
        vaccine: programmes.first.vaccines.find_by!(upload_name: "Cervarix")
      )

      create(
        :vaccination_record,
        programme: programmes.second,
        patient:,
        session:,
        performed_at: Date.new(2025, 1, 6),
        created_at: Time.zone.local(2025, 2, 15, 14, 33, 23),
        performed_by: nil,
        source: :manual_report,
        vaccine: nil
      )

      create(
        :vaccination_record,
        programme: programmes.third,
        patient:,
        session: nil,
        performed_at: Date.new(2025, 1, 24),
        created_at: Time.zone.local(2025, 2, 15, 14, 33, 23),
        performed_by: nil,
        source: :historical_upload,
        vaccine: nil
      )

      create(
        :notify_log_entry,
        :email,
        template_id:
          NotifyTemplate.find(:consent_school_request_hpv, channel: :email).id,
        consent_form: nil,
        patient:,
        programme_types: %w[hpv],
        recipient: "test@example.com",
        created_at: Date.new(2025, 5, 10),
        sent_by: user
      )
    end

    it "renders headings in correct order" do
      expect(rendered).to have_css(
        "li.app-timeline__item:nth-of-type(1)",
        text: /31 August 2025/
      )
      expect(rendered).to have_css(
        "li.app-timeline__item:nth-of-type(2)",
        text: /31 May 2025/
      )
      expect(rendered).to have_css(
        "li.app-timeline__item:nth-of-type(3)",
        text: /31 May 2025/
      )
      expect(rendered).to have_css(
        "li.app-timeline__item:nth-of-type(4)",
        text: /30 May 2025/
      )
    end

    it "has the expected number of timeline items" do
      expect(rendered).to have_css(".app-timeline__item", count: 13)
    end

    include_examples "card",
                     title: "Vaccinated with Gardasil 9",
                     date: "31 May 2025 at 12:00pm",
                     index: 2,
                     notes: "Some notes",
                     by: "JOY, Nurse",
                     programme: "HPV"

    include_examples "card",
                     title: "Vaccinated with Cervarix",
                     date: "31 May 2025 at 12:00pm",
                     index: 1,
                     notes: "Some notes millisecond later",
                     programme: "HPV"

    include_examples "card",
                     title: "Vaccination record added manually",
                     date:
                       "Record added to Mavis 15 February 2025 at 2:33pm · Vaccination given 6 January 2025",
                     programme: "Flu"

    include_examples "card",
                     title: "Vaccination record uploaded",
                     date:
                       "Record added to Mavis 15 February 2025 at 2:33pm · Vaccination given 24 January 2025",
                     programme: "MMR(V)"

    include_examples "card",
                     title: "Triaged decision: Safe to vaccinate",
                     date: "30 May 2025 at 2:30pm",
                     by: "JOY, Nurse",
                     programme: "HPV"

    include_examples "card",
                     title: "Triaged decision: Keep in triage",
                     date: "30 May 2025 at 2:00pm",
                     notes: "Some notes",
                     by: "JOY, Nurse",
                     programme: "HPV"

    include_examples "card",
                     title:
                       "Triaged decision: Safe to vaccinate with nasal spray",
                     date: "30 May 2025 at 2:35pm",
                     notes: "Some notes",
                     by: "JOY, Nurse",
                     programme: "Flu"

    include_examples "card",
                     title: "Consent refused by John Doe (dad)",
                     date: "30 May 2025 at 1:00pm",
                     programme: "HPV"

    include_examples "card",
                     title: "Consent given by Jane Doe (mum)",
                     date: "30 May 2025 at 12:00pm",
                     by: "JOY, Nurse",
                     programme: "HPV"

    include_examples "card",
                     title: "Added to the session at Hogwarts",
                     date: "29 May 2025 at 12:00pm"

    include_examples "card",
                     title: "Consent school request hpv sent",
                     date: "10 May 2025 at 12:00am",
                     notes: "test@example.com",
                     by: "JOY, Nurse",
                     programme: "HPV"

    context "when filtering by programme" do
      let(:component) do
        described_class.new(patient:, team:, programme_type: "hpv", session:)
      end

      it "has the expected number of timeline items" do
        expect(rendered).to have_css(".app-timeline__item", count: 9)
      end
    end
  end

  describe "patient specific directions" do
    before do
      create(
        :patient_specific_direction,
        created_at: Time.zone.local(2024, 6, 1, 12),
        created_by: user,
        patient:,
        programme: programmes.second,
        team:
      )

      create(
        :patient_specific_direction,
        created_at: Time.zone.local(2024, 6, 1, 10),
        invalidated_at: Time.zone.local(2024, 6, 1, 11),
        created_by: user,
        patient:,
        programme: programmes.second,
        team:
      )
    end

    include_examples "card",
                     title: "PSD added",
                     date: "1 June 2024 at 12:00pm",
                     by: "JOY, Nurse",
                     programme: "Flu"

    include_examples "card",
                     title: "PSD invalidated",
                     date: "1 June 2024 at 11:00am",
                     programme: "Flu"
  end

  describe "historical upload" do
    let(:date_and_time) { Time.zone.local(2026, 3, 4, 11, 30) }

    around { |example| travel_to(date_and_time) { example.run } }

    before do
      create(
        :vaccination_record,
        programme: programmes.first,
        patient:,
        performed_at: Date.new(2026, 1, 1),
        created_at: date_and_time,
        session: nil,
        source: :historical_upload
      )
    end

    include_examples "card",
                     title: "Vaccination record uploaded",
                     date:
                       "Record added to Mavis 4 March 2026 at 11:30am · Vaccination given 1 January 2026",
                     programme: "HPV"
  end

  describe "self-consent" do
    before do
      create(
        :consent,
        :given,
        :self_consent,
        programme: programmes.first,
        patient:,
        submitted_at: Time.zone.local(2025, 5, 30, 12)
      )
    end

    include_examples "card",
                     title:
                       "Consent given by DOE, Sarah (child (Gillick competent))",
                     date: "30 May 2025 at 12:00pm",
                     programme: "HPV"
  end

  describe "manually matched consent" do
    before do
      consent_form =
        create(
          :consent_form,
          session:,
          recorded_at: Time.zone.local(2025, 5, 30, 12),
          parent_full_name: "Jane Doe",
          parent_relationship_type: "mother"
        )

      create(
        :consent,
        :given,
        :invalidated,
        programme: programmes.first,
        patient:,
        parent: mum,
        consent_form:,
        recorded_by: user,
        created_at: Time.zone.local(2025, 5, 30, 13)
      )
    end

    include_examples "card",
                     title: "Consent given",
                     date: "30 May 2025 at 12:00pm",
                     by: "Jane Doe (mum)",
                     programme: "HPV"

    include_examples "card",
                     title:
                       "Consent response manually matched with child record",
                     date: "30 May 2025 at 1:00pm",
                     by: "JOY, Nurse"
  end

  describe "withdrawn consent" do
    before do
      create(
        :consent,
        :given,
        :withdrawn,
        programme: programmes.first,
        patient:,
        parent: mum,
        submitted_at: Time.zone.local(2025, 5, 30, 12),
        withdrawn_at: Time.zone.local(2025, 6, 30, 12)
      )
    end

    include_examples "card",
                     title: "Consent from Jane Doe withdrawn",
                     date: "30 June 2025 at 12:00pm",
                     programme: "HPV"

    include_examples "card",
                     title: "Consent given by Jane Doe (mum)",
                     date: "30 May 2025 at 12:00pm",
                     programme: "HPV"
  end

  describe "invalidated consent" do
    before do
      create(
        :consent,
        :given,
        :invalidated,
        programme: programmes.first,
        patient:,
        parent: mum,
        submitted_at: Time.zone.local(2025, 5, 30, 12),
        invalidated_at: Time.zone.local(2025, 6, 30, 12)
      )
    end

    include_examples "card",
                     title: "Consent from Jane Doe invalidated",
                     date: "30 June 2025 at 12:00pm",
                     programme: "HPV"

    include_examples "card",
                     title: "Consent given by Jane Doe (mum)",
                     date: "30 May 2025 at 12:00pm",
                     programme: "HPV"
  end

  describe "follow-up requested consent" do
    before do
      create(
        :consent,
        :follow_up_requested,
        programme: programmes.first,
        patient:,
        parent: mum,
        submitted_at: Time.zone.local(2025, 5, 30, 12)
      )
    end

    include_examples "card",
                     title: "Follow-up requested by Jane Doe (mum)",
                     date: "30 May 2025 at 12:00pm",
                     programme: "HPV"
  end

  describe "follow-up resolved consent (confirmed)" do
    before do
      create(
        :consent,
        :follow_up_requested,
        follow_up_requested: false,
        follow_up_outcome: "confirmed",
        follow_up_resolved_at: Time.zone.local(2025, 6, 30, 12),
        programme: programmes.first,
        patient:,
        parent: mum,
        submitted_at: Time.zone.local(2025, 5, 30, 12)
      )
    end

    include_examples "card",
                     title: "Follow-up requested by Jane Doe (mum)",
                     date: "30 May 2025 at 12:00pm",
                     programme: "HPV"

    include_examples "card",
                     title:
                       "Consent response from Jane Doe (mum) followed-up: " \
                         "refusal confirmed",
                     date: "30 June 2025 at 12:00pm",
                     programme: "HPV"
  end

  describe "follow-up resolved consent (withdrawn)" do
    before do
      create(
        :consent,
        :follow_up_requested,
        follow_up_outcome: "withdrawn",
        follow_up_resolved_at: Time.zone.local(2025, 6, 30, 12),
        invalidated_at: Time.zone.local(2025, 6, 30, 12),
        notes: "Consent given in follow-up discussion.",
        programme: programmes.first,
        patient:,
        parent: mum,
        submitted_at: Time.zone.local(2025, 5, 30, 12)
      )
      create(
        :consent,
        :given_verbally,
        programme: programmes.first,
        patient:,
        parent: mum,
        submitted_at: Time.zone.local(2025, 6, 30, 13)
      )
    end

    include_examples "card",
                     title: "Follow-up requested",
                     date: "30 May 2025 at 12:00pm",
                     programme: "HPV"

    include_examples "card",
                     title:
                       "Consent response from Jane Doe (mum) followed-up: " \
                         "refusal withdrawn",
                     date: "30 June 2025 at 12:00pm",
                     programme: "HPV"

    include_examples "card",
                     title: "Consent given by Jane Doe (mum)",
                     date: "30 June 2025 at 1:00pm",
                     programme: "HPV"

    it "does not render an 'invalidated' card for the old consent" do
      expect(rendered).not_to have_css(
        ".app-timeline__header",
        text: "Consent from Jane Doe invalidated"
      )
    end
  end

  describe "gillick assessments" do
    let(:programmes) { [Programme.td_ipv] }

    before do
      create(
        :gillick_assessment,
        :not_competent,
        performed_by: user,
        patient:,
        session:,
        notes: "Second notes",
        created_at: Time.zone.local(2025, 6, 1, 13)
      )
      create(
        :gillick_assessment,
        :competent,
        performed_by: user,
        patient:,
        session:,
        notes: "First notes",
        created_at: Time.zone.local(2025, 6, 1, 12)
      )
    end

    include_examples "card",
                     title: "Completed Gillick assessment as Gillick competent",
                     notes: "First notes",
                     date: "1 June 2025 at 12:00pm",
                     by: "JOY, Nurse",
                     programme: "Td/IPV"

    include_examples "card",
                     title:
                       "Updated Gillick assessment as not Gillick competent",
                     notes: "Second notes",
                     date: "1 June 2025 at 1:00pm",
                     by: "JOY, Nurse",
                     programme: "Td/IPV"
  end

  describe "notes" do
    let(:programmes) { [Programme.hpv] }
    let(:session) { create(:session, programmes:) }

    before do
      create(
        :note,
        created_by: user,
        patient:,
        session:,
        body: "A note.",
        created_at: Time.zone.local(2026, 6, 1, 12)
      )
    end

    include_examples "card",
                     title: "Note",
                     notes: "A note.",
                     date: "1 June 2026 at 12:00pm",
                     by: "JOY, Nurse",
                     programme: "HPV"
  end

  describe "pre-screenings" do
    let(:programmes) { [Programme.hpv] }
    let(:session) { create(:session, programmes:) }

    before do
      create(
        :pre_screening,
        performed_by: user,
        patient:,
        session:,
        notes: "Some notes",
        created_at: Time.zone.local(2025, 6, 1, 12)
      )
    end

    include_examples "card",
                     title: "Completed pre-screening checks",
                     notes: "Some notes",
                     date: "1 June 2025 at 12:00pm",
                     by: "JOY, Nurse",
                     programme: "HPV"
  end

  describe "vaccination records" do
    let(:programme) { Programme.hpv }

    context "for an administered vaccination record" do
      before do
        create(
          :vaccination_record,
          programme:,
          patient:,
          session:,
          performed_at: Time.zone.local(2025, 5, 31, 13),
          performed_by: user,
          notes: "Some notes.",
          vaccine: programme.vaccines.find_by!(upload_name: "Gardasil9")
        )
      end

      include_examples "card",
                       title: "Vaccinated with Gardasil 9",
                       date: "31 May 2025 at 1:00pm",
                       notes: "Some notes.",
                       by: "JOY, Nurse",
                       programme: "HPV"
    end

    context "for an MMRV variant record" do
      let(:programme) do
        Programme::Variant.new(Programme.mmr, variant_type: "mmrv")
      end

      before do
        create(
          :vaccination_record,
          patient:,
          programme:,
          session:,
          performed_at: Time.zone.local(2025, 5, 31, 13)
        )
      end

      include_examples "card",
                       title: "Vaccinated",
                       date: "31 May 2025 at 1:00pm",
                       programme: "MMRV"
    end

    context "for a not administered record" do
      before do
        create(
          :vaccination_record,
          :not_administered,
          programme:,
          patient:,
          session:,
          performed_at: Time.zone.local(2025, 5, 31, 13),
          performed_by: user,
          notes: "Some notes.",
          vaccine: programmes.first.vaccines.find_by!(upload_name: "Gardasil")
        )
      end

      include_examples "card",
                       title: "Vaccination not given: Unwell",
                       date: "31 May 2025 at 1:00pm",
                       notes: "Some notes.",
                       by: "JOY, Nurse",
                       programme: "HPV"
    end

    context "for a discarded record" do
      before do
        create(
          :vaccination_record,
          :discarded,
          programme:,
          patient:,
          session:,
          performed_at: Time.zone.local(2025, 5, 31, 13),
          discarded_at: Time.zone.local(2025, 5, 31, 14),
          performed_by: user
        )
      end

      include_examples "card",
                       title: "Vaccinated with Gardasil 9",
                       date: "31 May 2025 at 1:00pm",
                       by: "JOY, Nurse",
                       programme: "HPV"

      include_examples "card",
                       title: "Vaccination record archived",
                       date: "31 May 2025 at 2:00pm",
                       programme: "HPV"
    end

    context "for a discarded Imms API record" do
      before do
        create(
          :vaccination_record,
          :discarded,
          :sourced_from_nhs_immunisations_api,
          programme:,
          patient:,
          session:,
          performed_at: Time.zone.local(2025, 5, 31, 13),
          discarded_at: Time.zone.local(2025, 5, 31, 14),
          performed_by: user
        )
      end

      it "doesn't render card 'vaccinated'" do
        expect(rendered).not_to have_css(
          ".app-timeline__header",
          text: "Vaccinated with"
        )
      end

      it "doesn't render card 'archived'" do
        expect(rendered).not_to have_css(
          ".app-timeline__header",
          text: "Vaccination record archived"
        )
      end
    end
  end

  describe "patient merge events" do
    let(:component) { described_class.new(patient:, team:) }

    before do
      create(
        :patient_merge_log_entry,
        patient:,
        user:,
        created_at: Time.zone.local(2025, 6, 1, 12)
      )
    end

    include_examples "card",
                     title: "Child record merged",
                     date: "1 June 2025 at 12:00pm",
                     notes:
                       "The record for DOE, Sarah (date of birth 1 January 2010) was merged with the record " \
                         "for DOE, Sarah (date of birth 1 January 2010) because they have the same NHS number " \
                         "(9999075320).",
                     by: "JOY, Nurse"
  end

  describe "parent relationship removal events" do
    before do
      relationship =
        patient.parent_relationships.includes(:parent).find_by!(parent: mum)

      Audited.audit_class.as_user(user) { relationship.destroy! }
    end

    include_examples "card",
                     title: "Parent relationship removed",
                     date: "1 January 2026 at 12:00am",
                     notes: "Jane Doe (mum) removed from child record",
                     by: "JOY, Nurse"
  end

  describe "decision expiration events" do
    let(:hpv_programme) { Programme.hpv }
    let(:flu_programme) { Programme.flu }
    let(:programmes) { [hpv_programme, flu_programme] }

    context "with expired consent, triage, and PSD" do
      before do
        create(
          :consent,
          :given,
          programme: hpv_programme,
          patient:,
          parent: mum,
          academic_year: 2024,
          submitted_at: Time.zone.local(2024, 5, 30, 12)
        )

        create(
          :triage,
          :safe_to_vaccinate,
          programme: hpv_programme,
          patient:,
          academic_year: 2024,
          created_at: Time.zone.local(2024, 5, 30, 14, 30),
          performed_by: user
        )

        create(
          :patient_specific_direction,
          programme: hpv_programme,
          patient:,
          created_by: user,
          academic_year: 2024,
          created_at: Time.zone.local(2024, 5, 30, 15)
        )
      end

      include_examples "card",
                       title:
                         "Consent, health information, triage outcome and PSD status expired",
                       date: "31 August 2025 at 11:59pm",
                       notes: "DOE, Sarah was not vaccinated.",
                       programme: "HPV"
    end

    context "with only expired PSD" do
      before do
        create(
          :patient_specific_direction,
          programme: hpv_programme,
          patient:,
          created_by: user,
          academic_year: 2024,
          created_at: Time.zone.local(2024, 5, 30, 15)
        )
      end

      include_examples "card",
                       title: "PSD status expired",
                       date: "31 August 2025 at 11:59pm",
                       notes: "DOE, Sarah was not vaccinated.",
                       programme: "HPV"
    end

    context "with vaccinated patient" do
      before do
        create(
          :patient_specific_direction,
          programme: hpv_programme,
          patient:,
          created_by: user,
          academic_year: 2024,
          created_at: Time.zone.local(2025, 5, 30, 15)
        )

        create(:patient_location, patient:, session: session_last_year)

        create(
          :vaccination_record,
          patient:,
          programme: hpv_programme,
          session: session_last_year,
          performed_at: Time.zone.local(2025, 5, 30, 16)
        )

        PatientStatusUpdater.call(patient:)
      end

      it "does not render expired PSD card for vaccinated patient" do
        expect(rendered).not_to have_content("expired")
      end
    end

    context "with vaccinated but seasonal programme" do
      before do
        create(
          :consent,
          :given,
          programme: flu_programme,
          patient:,
          parent: mum,
          academic_year: 2024,
          submitted_at: Time.zone.local(2024, 5, 30, 12)
        )

        create(
          :triage,
          :safe_to_vaccinate,
          programme: flu_programme,
          patient:,
          academic_year: 2024,
          created_at: Time.zone.local(2024, 5, 30, 14, 30),
          performed_by: user
        )

        create(
          :patient_specific_direction,
          programme: flu_programme,
          patient:,
          created_by: user,
          academic_year: 2024,
          created_at: Time.zone.local(2024, 5, 30, 15)
        )

        create(
          :vaccination_record,
          patient:,
          programme: flu_programme,
          session: session_last_year,
          performed_at: 1.year.ago
        )
        patient.programme_status(flu_programme, academic_year: 2024).assign
      end

      include_examples "card",
                       title:
                         "Consent, health information, triage outcome and PSD status expired",
                       date: "31 August 2025 at 11:59pm",
                       notes: "DOE, Sarah was vaccinated.",
                       programme: "Flu"
    end
  end
end
