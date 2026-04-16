# frozen_string_literal: true

describe AppSessionSummaryComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(session) }

  let(:programmes) { [Programme.hpv] }
  let(:location) do
    create(
      :gias_school,
      :secondary,
      name: "Streeling University",
      urn: 123_456,
      address_postcode: "SW1A 1AA",
      programmes:
    )
  end
  let(:team) { create(:team, programmes:) }
  let(:outbreak) { false }
  let(:session) { create(:session, location:, programmes:, team:, outbreak:) }

  it { should have_content("ProgrammesHPV") }
  it { should have_content("Year groupsYears 8 to 11") }

  context "when showing the location" do
    let(:component) { described_class.new(session, show_location: true) }

    it { should have_content("Location") }
    it { should have_content("SW1A 1AA") }

    it { should have_content("School URN") }
    it { should have_content("123456") }
  end

  context "when showing the consent forms" do
    let(:component) { described_class.new(session, show_consent_forms: true) }

    it { should have_content("Consent forms") }
    it { should have_link("Download the HPV consent form (PDF)") }

    context "for MMR(V) programme" do
      let(:programmes) { [Programme.mmr] }

      it do
        expect(rendered).to have_link(
          "Download the MMR consent form (PDF)",
          href: /mmr/
        )
      end

      it do
        expect(rendered).to have_link(
          "Download the MMRV consent form (PDF)",
          href: /mmrv/
        )
      end
    end

    context "when consent is open" do
      let(:session) do
        create(:session, location:, date: 1.week.from_now.to_date, programmes:)
      end

      it do
        expect(rendered).to have_link(
          "View the HPV online consent form (opens in new tab)"
        )
      end

      context "for MMR(V) programme" do
        let(:programmes) { [Programme.mmr] }

        it "shows separate links for MMR and MMRV variants" do
          expect(rendered).to have_link(
            "View the MMR online consent form (opens in new tab)"
          )
          expect(rendered).to have_link(
            "View the MMRV online consent form (opens in new tab)"
          )
        end

        it "links to the correct MMR variant consent form" do
          expect(rendered).to have_link(
            "View the MMR online consent form (opens in new tab)",
            href: %r{/consents/#{session.slug}/mmr/start$}
          )
        end

        it "links to the correct MMRV variant consent form" do
          expect(rendered).to have_link(
            "View the MMRV online consent form (opens in new tab)",
            href: %r{/consents/#{session.slug}/mmrv/start$}
          )
        end
      end
    end
  end

  describe "consent style row" do
    context "session programme is MMR" do
      let(:programmes) { [Programme.mmr] }

      context "by default" do
        it { should_not have_content("Type of MMR(V) consent request") }
      end

      context "when showing consent style" do
        let(:component) do
          described_class.new(session, show_consent_style: true)
        end

        it { should have_content("Type of MMR(V) consent request") }

        context "session is set to outbreak = true" do
          let(:outbreak) { true }

          it { should have_content("Outbreak request") }
        end

        context "session is set to outbreak = false" do
          let(:outbreak) { false }

          it { should have_content("Standard request") }
        end
      end
    end

    context "session has multiple programmes including MMR" do
      let(:programmes) { [Programme.hpv, Programme.mmr] }

      context "by default" do
        it { should_not have_content("Type of MMR(V) consent request") }
      end

      context "when showing consent style" do
        let(:component) do
          described_class.new(session, show_consent_style: true)
        end

        it { should have_content("Type of MMR(V) consent request") }

        context "session is set to outbreak = true" do
          let(:outbreak) { true }

          it { should have_content("Outbreak request") }
        end

        context "session is set to outbreak = false" do
          let(:outbreak) { false }

          it { should have_content("Standard request") }
        end
      end
    end

    context "session does not have MMR programme" do
      let(:programmes) { [Programme.hpv] }

      context "by default" do
        it { should_not have_content("Type of MMR(V) consent request") }
      end

      context "when showing consent style" do
        let(:component) do
          described_class.new(session, show_consent_style: true)
        end

        it { should_not have_content("Type of MMR(V) consent request") }
      end
    end
  end
end
