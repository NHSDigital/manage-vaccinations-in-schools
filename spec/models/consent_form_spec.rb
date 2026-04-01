# frozen_string_literal: true

# == Schema Information
#
# Table name: consent_forms
#
#  id                                  :bigint           not null, primary key
#  address_line_1                      :string
#  address_line_2                      :string
#  address_postcode                    :string
#  address_town                        :string
#  archived_at                         :datetime
#  confirmation_sent_at                :datetime
#  date_of_birth                       :date
#  education_setting                   :integer
#  ethnic_background                   :integer
#  ethnic_background_other             :string
#  ethnic_group                        :integer
#  family_name                         :text
#  given_name                          :text
#  health_answers                      :jsonb            not null
#  nhs_number                          :string
#  notes                               :text             default(""), not null
#  parent_contact_method_other_details :string
#  parent_contact_method_type          :string
#  parent_email                        :string
#  parent_full_name                    :string
#  parent_phone                        :string
#  parent_phone_receive_updates        :boolean          default(FALSE), not null
#  parent_relationship_other_name      :string
#  parent_relationship_type            :string
#  preferred_family_name               :string
#  preferred_given_name                :string
#  recorded_at                         :datetime
#  school_confirmed                    :boolean
#  use_preferred_name                  :boolean
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  original_session_id                 :bigint
#  school_id                           :bigint
#  team_location_id                    :bigint           not null
#
# Indexes
#
#  index_consent_forms_on_nhs_number                  (nhs_number)
#  index_consent_forms_on_original_session_id         (original_session_id)
#  index_consent_forms_on_recorded                    (id) WHERE (recorded_at IS NOT NULL)
#  index_consent_forms_on_school_id                   (school_id)
#  index_consent_forms_on_team_location_id            (team_location_id)
#  index_consent_forms_on_unmatched_and_not_archived  (id) WHERE ((recorded_at IS NOT NULL) AND (archived_at IS NULL))
#
# Foreign Keys
#
#  fk_rails_...  (original_session_id => sessions.id)
#  fk_rails_...  (school_id => locations.id)
#  fk_rails_...  (team_location_id => team_locations.id)
#

describe ConsentForm do
  subject(:consent_form) { build(:consent_form) }

  it_behaves_like "a Confirmable model"

  describe "associations" do
    it { should have_many(:consents) }
  end

  describe "scopes" do
    let(:programme) { Programme.sample }
    let(:session) { create(:session, programmes: [programme]) }

    describe "#unmatched" do
      subject(:scope) { described_class.unmatched }

      let(:unmatched_consent_form) do
        create(:consent_form, :recorded, session:)
      end
      let(:matched_consent_form) { create(:consent_form, :recorded, session:) }

      before do
        create(:consent, programme:, consent_form: matched_consent_form)
      end

      it { should include(unmatched_consent_form) }
      it { should_not include(matched_consent_form) }
    end

    describe "#recorded" do
      subject(:scope) { described_class.recorded }

      let(:recorded_consent_form) { create(:consent_form, :recorded, session:) }
      let(:draft_consent_form) { create(:consent_form, session:) }

      it { should include(recorded_consent_form) }
      it { should_not include(draft_consent_form) }
    end
  end

  describe "validations" do
    subject(:consent_form) do
      create(
        :consent_form,
        health_answers:,
        parent_phone_receive_updates:,
        reason_for_refusal:,
        response:,
        session:,
        programmes:,
        use_preferred_name:,
        wizard_step:
      )
    end

    let(:health_answers) { [] }
    let(:parent_phone_receive_updates) { false }
    let(:reason_for_refusal) { nil }
    let(:response) { nil }
    let(:session) { create(:session, programmes:) }
    let(:programmes) { [Programme.hpv] }
    let(:use_preferred_name) { false }
    let(:wizard_step) { nil }

    it { should validate_presence_of(:given_name).on(:update) }
    it { should validate_presence_of(:family_name).on(:update) }
    it { should validate_presence_of(:date_of_birth).on(:update) }
    it { should_not validate_presence_of(:school_confirmed).on(:update) }

    it { should_not validate_presence_of(:parent_phone) }

    context "when users wants to receive text updates" do
      let(:parent_phone_receive_updates) { true }

      it { should validate_presence_of(:parent_phone) }
    end

    context "when wizard_step is :name" do
      let(:wizard_step) { :name }

      it { should validate_presence_of(:given_name).on(:update) }
      it { should validate_presence_of(:family_name).on(:update) }

      context "when use_preferred_name is true" do
        let(:use_preferred_name) { true }

        it { should validate_presence_of(:preferred_given_name).on(:update) }
        it { should validate_presence_of(:preferred_family_name).on(:update) }
      end
    end

    context "when wizard_step is :date_of_birth" do
      let(:wizard_step) { :date_of_birth }

      context "runs validations from previous steps" do
        it { should validate_presence_of(:given_name).on(:update) }
      end

      it { should validate_presence_of(:date_of_birth).on(:update) }

      context "with a date of birth that's too young" do
        before { travel_to(Date.new(2022, 1, 1)) }

        it "has the correct error message" do
          consent_form.date_of_birth = 2.years.ago.to_date
          consent_form.valid?(:update)
          # the date formatting below relies on the
          # custom interpolation from I18n::CustomInterpolation
          expect(consent_form.errors[:date_of_birth]).to contain_exactly(
            "The child cannot be younger than 3. Enter a date before 1 January 2019."
          )
        end
      end

      context "with a date of birth that's too old" do
        before { travel_to(Date.new(2022, 1, 1)) }

        it "has the correct error message" do
          consent_form.date_of_birth = 23.years.ago.to_date
          consent_form.valid?(:update)
          # the date formatting below relies on the
          # custom interpolation from I18n::CustomInterpolation
          expect(consent_form.errors[:date_of_birth]).to contain_exactly(
            "The child cannot be older than 22. Enter a date after 1 January 2000."
          )
        end
      end
    end

    context "when wizard_step is :parent" do
      let(:wizard_step) { :parent }

      context "runs validations from previous steps" do
        it { should validate_presence_of(:given_name).on(:update) }
        it { should validate_presence_of(:date_of_birth).on(:update) }
      end
    end

    context "when wizard_step is :response_doubles" do
      let(:wizard_step) { :response_doubles }

      let(:programmes) { [Programme.menacwy, Programme.td_ipv] }

      context "runs validations from previous steps" do
        it { should validate_presence_of(:given_name).on(:update) }
        it { should validate_presence_of(:date_of_birth).on(:update) }
      end

      it do
        expect(consent_form).to validate_inclusion_of(:response).on(
          :update
        ).in_array(%w[given given_one refused])
      end
    end

    context "when wizard_step is :response_flu" do
      let(:wizard_step) { :response_flu }

      let(:programmes) { [Programme.flu] }

      context "runs validations from previous steps" do
        it { should validate_presence_of(:given_name).on(:update) }
        it { should validate_presence_of(:date_of_birth).on(:update) }
      end

      it do
        expect(consent_form).to validate_inclusion_of(:response).on(
          :update
        ).in_array(%w[given_injection given_nasal refused])
      end
    end

    context "when wizard_step is :response_hpv" do
      let(:wizard_step) { :response_hpv }

      context "runs validations from previous steps" do
        it { should validate_presence_of(:given_name).on(:update) }
        it { should validate_presence_of(:date_of_birth).on(:update) }
      end

      it do
        expect(consent_form).to validate_inclusion_of(:response).on(
          :update
        ).in_array(%w[given refused])
      end
    end

    context "when wizard_step is :response_mmr" do
      let(:wizard_step) { :response_mmr }

      let(:programmes) { [Programme.mmr] }

      context "runs validations from previous steps" do
        it { should validate_presence_of(:given_name).on(:update) }
        it { should validate_presence_of(:date_of_birth).on(:update) }
      end

      it do
        expect(consent_form).to validate_inclusion_of(:response).on(
          :update
        ).in_array(%w[given refused])
      end
    end

    context "when wizard_step is :reason_for_refusal" do
      let(:response) { "refused" }
      let(:wizard_step) { :reason_for_refusal }

      context "runs validations from previous steps" do
        it { should validate_presence_of(:given_name).on(:update) }
        it { should validate_presence_of(:date_of_birth).on(:update) }
      end

      it { should validate_presence_of(:reason_for_refusal).on(:update) }
    end

    context "when wizard_step is :reason_for_refusal_notes" do
      let(:response) { "refused" }
      let(:reason_for_refusal) { "medical_reasons" }
      let(:wizard_step) { :reason_for_refusal_notes }

      context "runs validations from previous steps" do
        it { should validate_presence_of(:given_name).on(:update) }
        it { should validate_presence_of(:date_of_birth).on(:update) }
      end

      it { should validate_presence_of(:reason_for_refusal_notes).on(:update) }
    end

    context "when wizard_step is :address" do
      let(:response) { "given" }
      let(:wizard_step) { :address }

      context "runs validations from previous steps" do
        it { should validate_presence_of(:given_name).on(:update) }
        it { should validate_presence_of(:date_of_birth).on(:update) }
      end

      it { should validate_presence_of(:address_line_1).on(:update) }
      it { should validate_presence_of(:address_town).on(:update) }
      it { should validate_presence_of(:address_postcode).on(:update) }

      it do
        expect(consent_form).not_to allow_value("invalid").for(
          :address_postcode
        ).on(:update)
      end
    end

    context "when wizard_step is :health_question" do
      let(:response) { "given" }
      let(:wizard_step) { :health_question }
      let(:health_answers) do
        [
          HealthAnswer.new(
            id: 0,
            question: "Has your child been diagnosed with asthma?",
            next_question: 2,
            follow_up_question: 1
          ),
          HealthAnswer.new(
            id: 1,
            question: "Have they taken oral steroids in the last 2 weeks?",
            next_question: 2
          ),
          HealthAnswer.new(
            id: 2,
            question:
              "Has your child had a flu vaccination in the last 5 months?"
          )
        ]
      end

      describe "validations from previous steps" do
        it { should validate_presence_of(:given_name).on(:update) }
        it { should validate_presence_of(:date_of_birth).on(:update) }
        it { should validate_presence_of(:address_line_1).on(:update) }
        it { should validate_presence_of(:address_town).on(:update) }
        it { should validate_presence_of(:address_postcode).on(:update) }
      end

      it "is valid if the default health answers have responses" do
        health_answers[0].response = "no"
        health_answers[2].response = "no"

        consent_form.save # rubocop:disable Rails/SaveBang
        expect(consent_form).to be_valid
      end

      it "is invalid if health answers do not have responses" do
        consent_form.save # rubocop:disable Rails/SaveBang
        expect(consent_form).not_to be_valid
      end

      it "checks follow-up questions if necessary" do
        health_answers[0].response = "yes"
        health_answers[0].notes = "for the tests"
        health_answers[2].response = "no"

        consent_form.save # rubocop:disable Rails/SaveBang
        expect(consent_form).not_to be_valid
      end

      context "health_question_number is set" do
        it "only validates the given health answer" do
          consent_form.health_question_number = 1
          consent_form.health_answers[1].response = "no"

          consent_form.save # rubocop:disable Rails/SaveBang
          expect(consent_form).to be_valid
        end
      end
    end

    context "when wizard_step is :ethnicity_question" do
      let(:wizard_step) { :ethnicity }

      it do
        expect(consent_form).to validate_inclusion_of(:ethnicity_question).on(
          :ethnicity_update
        ).in_array(%w[yes no])
      end
    end

    context "when wizard_step is :ethnic_group" do
      let(:wizard_step) { :ethnic_group }

      it { should validate_presence_of(:ethnic_group).on(:ethnicity_update) }
    end

    context "when wizard_step is :ethnic_background" do
      let(:wizard_step) { :ethnic_background }

      it do
        expect(consent_form).to validate_presence_of(:ethnic_background).on(
          :ethnicity_update
        )
      end
    end
  end

  it { should normalize(:given_name).from(" Joanna ").to("Joanna") }
  it { should normalize(:family_name).from(" Smith ").to("Smith") }
  it { should normalize(:address_postcode).from(" SW111AA ").to("SW11 1AA") }

  it_behaves_like "a model with a normalised email address", :parent_email
  it_behaves_like "a model with a normalised phone number", :parent_phone

  describe "#full_name" do
    it "returns the full name as a string" do
      consent_form =
        build(:consent_form, given_name: "John", family_name: "Doe")
      expect(consent_form.full_name).to eq("DOE, John")
    end
  end

  describe "#wizard_steps" do
    it "does not ask for reason_for_refusal for refusal when patient gives consent" do
      consent_form = create(:consent_form, response: "given")
      expect(consent_form.wizard_steps).not_to include(:reason_for_refusal)
    end

    it "asks for details when patient refuses for a few different reasons" do
      session = create(:session)

      %w[
        medical_reasons
        will_be_vaccinated_elsewhere
        other
        already_vaccinated
      ].each do |reason_for_refusal|
        consent_form =
          create(
            :consent_form,
            response: "refused",
            reason_for_refusal:,
            session:
          )
        expect(consent_form.wizard_steps).to include(:reason_for_refusal_notes)
      end
    end

    it "skips asking for details when patient refuses due to gelatine content or pesonal reason" do
      session = create(:session)

      %w[contains_gelatine personal_choice].each do |reason_for_refusal|
        consent_form =
          build(
            :consent_form,
            response: "refused",
            reason_for_refusal:,
            session:
          )
        expect(consent_form.wizard_steps).not_to include(
          :reason_for_refusal_notes
        )
      end
    end
  end

  describe "#address_postcode=" do
    it "formats the postcode" do
      consent_form = build(:consent_form, address_postcode: "sw1a1aa")
      expect(consent_form.address_postcode).to eq("SW1A 1AA")
    end

    it "leaves nil as nil" do
      consent_form = build(:consent_form, address_postcode: nil)
      expect(consent_form.address_postcode).to be_nil
    end
  end

  describe "#each_health_answer" do
    context "linear health questions without branching" do
      let(:consent_form) do
        build(:consent_form, :with_health_answers_no_branching)
      end

      context "no answers recorded" do
        it "yields all the health answers in order" do
          expect { |b| consent_form.each_health_answer(&b) }.to(
            yield_successive_args(
              consent_form.health_answers[0],
              consent_form.health_answers[1],
              consent_form.health_answers[2]
            )
          )
        end
      end

      context "no answers requiring follow-up recorded" do
        it "yields all the health answers in order" do
          consent_form.health_answers[0].response = "no"
          consent_form.health_answers[2].response = "no"

          expect { |b| consent_form.each_health_answer(&b) }.to(
            yield_successive_args(
              consent_form.health_answers[0],
              consent_form.health_answers[1],
              consent_form.health_answers[2]
            )
          )
        end
      end

      context "answers require follow-up recorded" do
        it "yields all the health answers in order" do
          consent_form.health_answers[0].response = "yes"
          consent_form.health_answers[1].response = "yes"
          consent_form.health_answers[2].response = "yes"

          expect { |b| consent_form.each_health_answer(&b) }.to(
            yield_successive_args(
              consent_form.health_answers[0],
              consent_form.health_answers[1],
              consent_form.health_answers[2]
            )
          )
        end
      end
    end

    context "health answers with branching" do
      let(:consent_form) do
        build(:consent_form, :with_health_answers_asthma_branching)
      end

      context "no answers recorded" do
        it "yields all the health answers in order" do
          expect { |b| consent_form.each_health_answer(&b) }.to(
            yield_successive_args(
              consent_form.health_answers[0],
              consent_form.health_answers[1],
              consent_form.health_answers[2]
            )
          )
        end
      end

      context "no answers requiring follow-up" do
        it "yields the non follow-up health answers in order" do
          consent_form.health_answers[0].response = "no"
          consent_form.health_answers[2].response = "no"

          expect { |b| consent_form.each_health_answer(&b) }.to(
            yield_successive_args(
              consent_form.health_answers[0],
              consent_form.health_answers[2]
            )
          )
        end
      end

      context "answers require follow-up" do
        it "yields the normal and follow-up health answer in order" do
          consent_form.health_answers[0].response = "yes"
          consent_form.health_answers[1].response = "yes"
          consent_form.health_answers[2].response = "yes"

          expect { |b| consent_form.each_health_answer(&b) }.to(
            yield_successive_args(
              consent_form.health_answers[0],
              consent_form.health_answers[1],
              consent_form.health_answers[2]
            )
          )
        end
      end
    end

    context "accidental infinite loop" do
      it "raises an error" do
        consent_form = build :consent_form
        consent_form.health_answers[0].next_question = 0

        expect { |_b| consent_form.each_health_answer { nil } }.to(
          raise_error("Infinite loop detected")
        )
      end
    end
  end

  describe "#health_answers_require_triage?" do
    subject { consent_form.health_answers_require_triage? }

    let(:consent_form) do
      build(:consent_form, :with_health_answers_no_branching)
    end

    it { should be(false) }

    context "some responses are yes" do
      before { consent_form.health_answers[0].response = "yes" }

      it { should be(true) }
    end

    context "with follow-up questions" do
      let(:consent_form) do
        build(:consent_form, :with_health_answers_asthma_branching)
      end

      it { should be(false) }

      context "when follow-up question is yes" do
        before { consent_form.health_answers[1].response = "yes" }

        it { should be(true) }
      end
    end

    context "when providing an answer to the any other medical conditions question" do
      let(:team) { create(:team, ods_code: "ABC") }
      let(:programmes) { [Programme.flu] }

      let(:consent_form) do
        build(
          :consent_form,
          team:,
          programmes:,
          academic_year: AcademicYear.current,
          location: create(:school, programmes:),
          session: nil,
          health_answers: [
            HealthAnswer.new(
              id: 0,
              question:
                "Does the child have any severe allergies that have led to an anaphylactic reaction?",
              next_question: 1,
              response: "no",
              would_require_triage: true
            ),
            HealthAnswer.new(
              id: 1,
              question:
                "Does your child have any other medical conditions the immunisation team should be aware of?",
              response: "yes",
              would_require_triage: false
            )
          ]
        )
      end

      it { should be(false) }

      context "and when acting as Leicestershire" do
        let(:team) do
          create(:team, ods_code: "RT5", workgroup: "leicestershiresais")
        end

        before do
          HealthAnswer.remove_instance_variable(:@leicestershire_team_id)
        end

        it { should be(true) }
      end
    end
  end

  describe "#vaccine_may_contain_gelatine?" do
    subject { consent_form.vaccine_may_contain_gelatine? }

    let(:consent_form) do
      create(:consent_form, session: create(:session, programmes:))
    end

    before { consent_form.strict_loading!(false) }

    context "if the flu programme offers both injection and nasal vaccines" do
      let(:programmes) { [Programme.flu] }

      it { should be(true) }
    end

    context "for an HPV programme" do
      let(:programmes) { [Programme.hpv] }

      it { should be(false) }
    end
  end

  describe "#session" do
    subject { consent_form.session }

    let(:programmes) { [Programme.hpv] }
    let(:team) { create(:team, programmes:) }

    let!(:school) { create(:school, team:) }
    let!(:generic_clinic) { team.generic_clinic }

    context "with a consent form from a school" do
      let(:consent_form) do
        create(
          :consent_form,
          team:,
          programmes:,
          location: school,
          academic_year: AcademicYear.current,
          session: nil
        )
      end

      context "with no school session" do
        it { should be_nil }
      end

      context "with an unscheduled school session" do
        let!(:school_session) do
          create(:session, :unscheduled, location: school, team:, programmes:)
        end

        it { should eq(school_session) }
      end

      context "with an unscheduled and scheduled school session" do
        before do
          create(:session, :unscheduled, location: school, team:, programmes:)
        end

        let!(:scheduled_school_session) do
          create(:session, :scheduled, location: school, team:, programmes:)
        end

        it { should eq(scheduled_school_session) }
      end
    end

    context "with a consent form from a school to the clinic" do
      let(:consent_form) do
        create(
          :consent_form,
          :education_setting_home,
          team:,
          programmes:,
          location: school,
          academic_year: AcademicYear.current,
          session: nil
        )
      end

      context "with no school session" do
        it { should be_nil }
      end

      context "with an unscheduled school session" do
        before do
          create(:session, :unscheduled, location: school, team:, programmes:)
        end

        it { should be_nil }
      end

      context "with an unscheduled and scheduled school session" do
        before do
          create(:session, :unscheduled, location: school, team:, programmes:)
          create(:session, :scheduled, location: school, team:, programmes:)
        end

        it { should be_nil }
      end
    end

    context "with a consent form from a clinic" do
      let(:consent_form) do
        create(
          :consent_form,
          :education_setting_home,
          team:,
          programmes:,
          location: generic_clinic,
          academic_year: AcademicYear.current,
          session: nil
        )
      end

      context "with no school session" do
        it { should be_nil }
      end

      context "with an unscheduled school session" do
        before do
          create(:session, :unscheduled, location: school, team:, programmes:)
        end

        it { should be_nil }
      end

      context "with an unscheduled and scheduled school session" do
        before do
          create(:session, :unscheduled, location: school, team:, programmes:)
          create(:session, :scheduled, location: school, team:, programmes:)
        end

        it { should be_nil }
      end
    end
  end

  it "seeds the health questions when the parent gives consent" do
    consent_form =
      create(
        :consent_form,
        session: create(:session, programmes: [Programme.hpv]),
        response: "refused"
      )

    consent_form.consent_form_programmes.update!(
      response: "given",
      vaccine_methods: %w[injection]
    )
    consent_form.update!(
      address_line_1: "123 Fake St",
      address_town: "London",
      address_postcode: "SW1A 1AA"
    )
    consent_form.reload.seed_health_questions

    expect(consent_form.health_answers).not_to be_empty
  end

  it "removes the health questions when the parent refuses consent for flu" do
    consent_form =
      create(
        :consent_form,
        :with_health_answers_no_branching,
        session: create(:session, programmes: [Programme.flu]),
        response: nil
      )

    consent_form.update!(
      response: "refused",
      reason_for_refusal: "personal_choice"
    )

    expect(consent_form.health_answers).to be_empty
  end

  it "combines health questions from multiple active vaccines" do
    programme1 = Programme.menacwy
    programme2 = Programme.td_ipv

    session = create(:session, programmes: [programme1, programme2])

    consent_form = create(:consent_form, :refused, session:)

    consent_form.update!(
      response: "given",
      address_line_1: "123 Fake St",
      address_town: "London",
      address_postcode: "SW1A 1AA"
    )

    consent_form.seed_health_questions

    # there's only one extra question, the other questions are the same for both programmes
    expect(consent_form.health_answers.count).to eq(
      programme1.vaccines.first.health_questions.count + 1
    )
  end

  it "only shows the health questions for the chosen vaccine" do
    programme1 = Programme.menacwy
    programme2 = Programme.td_ipv
    consent_form =
      create(
        :consent_form,
        session: create(:session, programmes: [programme1, programme2]),
        programmes: [programme1, programme2],
        response: "refused"
      )

    consent_form.consent_form_programmes.second.update!(
      response: "given",
      vaccine_methods: %w[injection]
    )
    consent_form.update!(
      reason_for_refusal: "personal_choice",
      address_line_1: "123 Fake St",
      address_town: "London",
      address_postcode: "SW1A 1AA"
    )
    consent_form.reload.seed_health_questions

    expect(consent_form.health_answers.count).to eq(
      programme2.vaccines.first.health_questions.count
    )
  end

  it "removes the health questions when the parent refuses consent for HPV" do
    consent_form =
      create(
        :consent_form,
        :with_health_answers_no_branching,
        session: create(:session, programmes: [Programme.hpv]),
        response: nil
      )

    consent_form.update!(
      response: "refused",
      reason_for_refusal: "personal_choice"
    )
    consent_form.reload

    expect(consent_form.health_answers).to be_empty
  end

  it "leaves the health questions when the parent gives consent" do
    consent_form =
      create(:consent_form, :with_health_answers_no_branching, response: nil)

    consent_form.update!(response: "given")
    consent_form.reload

    expect(consent_form.health_answers).not_to be_empty
  end

  describe "#summary_with_route" do
    subject { consent_form.summary_with_route }

    let(:consent_form) { create(:consent_form, response:) }

    context "when given" do
      let(:response) { "given" }

      it { should eq("Consent given (online)") }
    end

    context "when refused" do
      let(:response) { "refused" }

      it { should eq("Consent refused (online)") }
    end
  end

  describe "#match_with_patient!" do
    subject(:match_with_patient!) do
      consent_form.match_with_patient!(patient, current_user:)
    end

    let(:programme) { Programme.sample }
    let(:team) { create(:team, programmes: [programme]) }

    let(:school) { create(:school, programmes: [programme]) }
    let(:location) { school }
    let(:session) do
      create(:session, team:, programmes: [programme], location:)
    end
    let(:patient) { create(:patient, school:, session:) }
    let(:current_user) { create(:user) }

    let(:notify_log_entry) do
      create(:notify_log_entry, :email, consent_form:, patient: nil)
    end

    context "when the consent form is draft" do
      let(:consent_form) { create(:consent_form, team:, session:) }

      it "raises an error" do
        expect { match_with_patient! }.to raise_error(
          Consent::ConsentFormNotRecorded
        )
      end
    end

    context "when consent form confirms the school" do
      let(:consent_form) do
        create(
          :consent_form,
          :recorded,
          team:,
          session:,
          school_confirmed: true
        )
      end

      it "creates a consent" do
        expect { match_with_patient! }.to change(Consent, :count).by(1)
      end

      it "doesn't change the patient's school" do
        expect { match_with_patient! }.not_to change(patient, :school)
      end

      it "assigns any notify log entries" do
        expect { match_with_patient! }.to change {
          notify_log_entry.reload.patient
        }.from(nil).to(patient)
      end
    end

    context "when the consent form was submitted a week ago" do
      let(:consent_form) do
        create(
          :consent_form,
          recorded_at: 1.week.ago,
          team:,
          session:,
          school_confirmed: true
        )
      end

      it "creates a consent submitted a week ago" do
        expect { match_with_patient! }.to change(Consent, :count).by(1)

        expect(Consent.last.submitted_at).to eq(consent_form.recorded_at)
      end
    end

    context "when the patient goes to a different school" do
      let(:consent_form) do
        create(
          :consent_form,
          :recorded,
          team:,
          session:,
          school_confirmed: false,
          school: new_school
        )
      end

      let(:new_school) { create(:school) }

      it "creates a consent" do
        expect { match_with_patient! }.to change(Consent, :count).by(1)
      end

      it "doesn't change the patient's school" do
        expect { match_with_patient! }.not_to change(patient, :school)
      end

      it "creates a school move" do
        expect { match_with_patient! }.to change(
          patient.school_moves,
          :count
        ).by(1)

        school_move = patient.school_moves.first
        expect(school_move.school_id).to eq(new_school.id)
      end
    end

    context "when the patient is home educated" do
      let(:consent_form) do
        create(
          :consent_form,
          :recorded,
          team:,
          session:,
          school_confirmed: nil,
          education_setting: "home"
        )
      end

      let(:new_location) { create(:generic_clinic, team:) }

      it "creates a consent" do
        expect { match_with_patient! }.to change(Consent, :count).by(1)
      end

      it "doesn't change the patient's school" do
        expect { match_with_patient! }.not_to change(patient, :school)
      end

      it "creates a school move" do
        expect { match_with_patient! }.to change(
          patient.school_moves,
          :count
        ).by(1)

        school_move = patient.school_moves.includes(:school).first
        expect(school_move.school).to eq(team.home_educated_school)
      end
    end
  end

  describe "#matches_contact_details_for" do
    subject(:matches_contact_details_for) do
      consent_form.matches_contact_details_for?(patient:)
    end

    let(:parent) do
      create(
        :parent,
        email: "existing@example.com",
        phone: "07987654321",
        phone_receive_updates: true
      )
    end
    let(:patient) { create(:patient, parents: [parent]) }
    let(:consent_form) do
      create(
        :consent_form,
        parent_email: "submitted@example.com",
        parent_phone: "07123456789"
      )
    end

    it { should be(false) }

    context "when patient has no parents" do
      let(:patient) { create(:patient, parents: []) }

      it { should be(true) }
    end

    context "when submitted email and phone both match existing parent" do
      let(:consent_form) do
        create(
          :consent_form,
          parent_email: "existing@example.com",
          parent_phone: "07987654321"
        )
      end

      it { should be(true) }
    end

    context "when only submitted email matches existing parent" do
      let(:consent_form) do
        create(
          :consent_form,
          parent_email: "existing@example.com",
          parent_phone: "07111111111"
        )
      end

      it { should be(true) }
    end

    context "when only submitted phone matches existing parent" do
      let(:consent_form) do
        create(
          :consent_form,
          parent_email: "different@example.com",
          parent_phone: "07987654321"
        )
      end

      it { should be(true) }
    end
  end

  context "when resetting unused fields" do
    let(:programmes) { [Programme.sample] }
    let(:session) { create(:session, programmes:) }

    it "resets preferred_given_name when use_preferred_name is set to false" do
      consent_form =
        create(
          :consent_form,
          preferred_given_name: "John",
          use_preferred_name: true,
          session:
        )
      consent_form.update!(use_preferred_name: false)
      expect(consent_form.preferred_given_name).to be_nil
    end

    it "resets reason_for_refusal and notes when response changes from refused to given" do
      consent_form =
        create(
          :consent_form,
          response: "refused",
          reason_for_refusal: "contains_gelatine",
          reason_for_refusal_notes: "I'm vegan",
          session:
        )
      consent_form.update!(response: "given")
      consent_form.consent_form_programmes.each do |consent_form_programme|
        expect(consent_form_programme.reason_for_refusal).to be_nil
        expect(consent_form_programme.notes).to eq("")
      end
    end

    it "resets address fields when response is changed to refused" do
      consent_form = create(:consent_form, session:)
      consent_form.update!(response: "refused")
      expect(consent_form.address_line_1).to be_nil
      expect(consent_form.address_line_2).to be_nil
      expect(consent_form.address_town).to be_nil
      expect(consent_form.address_postcode).to be_nil
    end
  end
end
