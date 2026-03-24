# frozen_string_literal: true

describe GIAS do
  describe ".download" do
    subject(:download) { described_class.download(output_file:) }

    let(:output_file) { "tmp/dfe-schools.zip" }
    let(:mechanize_agent) { instance_double(Mechanize) }
    let(:page) { instance_double(Mechanize::Page) }
    let(:form) { instance_double(Mechanize::Form) }
    let(:checkbox) { instance_double(Mechanize::Form::CheckBox) }
    let(:links_checkbox) { instance_double(Mechanize::Form::CheckBox) }
    let(:download_page) { instance_double(Mechanize::Page) }
    let(:download_form) { instance_double(Mechanize::Form) }
    let(:download_button) { instance_double(Mechanize::Form::Button) }
    let(:download_file) { instance_double(Mechanize::File) }

    before do
      allow(Mechanize).to receive(:new).and_return(mechanize_agent)
      allow(mechanize_agent).to receive(:user_agent_alias=)
      allow(mechanize_agent).to receive(:get).with(
        "https://get-information-schools.service.gov.uk/Downloads"
      ).and_return(page)
      allow(page).to receive(:form_with).with(
        action: "/Downloads/Collate"
      ).and_return(form)
      allow(form).to receive(:checkbox_with).with(
        id: "establishment-fields-csv-checkbox"
      ).and_return(checkbox)
      allow(form).to receive(:checkbox_with).with(
        id: "establishment-links-csv-checkbox"
      ).and_return(links_checkbox)
      allow(checkbox).to receive(:check)
      allow(links_checkbox).to receive(:check)
      allow(form).to receive(:submit).and_return(download_page)
      allow(download_page).to receive(:form_with).with(
        action: "/Downloads/Download/Extract"
      ).and_return(download_form)
      allow(download_form).to receive(:button_with).with(
        value: "Results.zip"
      ).and_return(download_button)
      allow(mechanize_agent).to receive(:click).with(
        download_button
      ).and_return(download_file)
      allow(download_file).to receive(:save!).with(output_file)
    end

    it "downloads the file successfully" do
      expect(download).to be true
      expect(download_file).to have_received(:save!).with(output_file)
    end

    context "when download button never appears" do
      before do
        allow(download_page).to receive(:form_with).with(
          action: "/Downloads/Download/Extract"
        ).and_return(nil)
        allow(download_page).to receive(:uri).and_return("https://some-uri")
        allow(mechanize_agent).to receive(:get).with(
          "https://some-uri"
        ).and_return(download_page)
        # Mocking sleep to speed up tests
        allow(described_class).to receive(:sleep)
      end

      it "returns false after timeout" do
        expect(download).to be false
      end
    end
  end

  describe ".import" do
    subject(:import) { described_class.import(input_file:) }

    let(:input_file) { "spec/fixtures/files/dfe-schools.zip" }

    it "imports schools correctly" do
      expect { described_class.import(input_file:) }.to change(
        Location,
        :count
      ).by(5)

      school = Location.find_by(urn: "100000")
      expect(school.name).to eq("The Aldgate School")
      expect(school.gias_local_authority_code).to eq(201)
      expect(school.gias_establishment_number).to eq(3614)
      expect(school.gias_phase).to eq("primary")
      expect(school.status).to eq("closed")
    end

    it "updates existing schools" do
      create(:gias_school, urn: "100000", name: "Old Name")
      import
      expect(Location.find_by(urn: "100000").name).to eq("The Aldgate School")
    end

    it "updates sites" do
      create(:gias_school, urn: "100000", site: "A", name: "Site A")
      import
      site = Location.find_by(urn: "100000", site: "A")
      expect(site.status).to eq("closed") # closed, same as main school in CSV
    end
  end

  describe ".check_import" do
    let(:input_file) { "spec/fixtures/files/dfe-schools.zip" }

    it "returns correct counts" do
      programme = Programme.hpv
      team = create(:team, ods_code: "A9A5A", programmes: [programme])
      school = create(:gias_school, urn: "100000", gias_year_groups: [1, 2, 3])
      create(
        :session,
        location: school,
        date: Date.tomorrow,
        programmes: [programme],
        team: team
      )

      results = described_class.check_import(input_file:)

      expect(results[:new_schools]).to include("100003")
      expect(results[:schools_with_future_sessions][:closed]).to have_key(
        "100000"
      )
      expect(results[:schools_with_future_sessions][:closed]["100000"]).to eq(
        ["100004"]
      )
      expect(
        results[:schools_with_future_sessions][:year_group_changes]
      ).to have_key("100000")
    end
  end

  describe ".process_url" do
    it "adds https if missing" do
      expect(described_class.process_url("example.com")).to eq(
        "https://example.com"
      )
    end

    it "keeps existing http/https" do
      expect(described_class.process_url("http://example.com")).to eq(
        "http://example.com"
      )
      expect(described_class.process_url("https://example.com")).to eq(
        "https://example.com"
      )
    end

    it "fixes malformed http:www" do
      expect(described_class.process_url("http:www.example.com")).to eq(
        "http://www.example.com"
      )
    end

    it "returns nil for blank" do
      expect(described_class.process_url("")).to be_nil
      expect(described_class.process_url(nil)).to be_nil
    end
  end

  describe ".process_year_groups" do
    it "calculates year groups correctly" do
      row = { "StatutoryLowAge" => "4", "StatutoryHighAge" => "11" }
      expect(described_class.process_year_groups(row)).to eq((0..6).to_a)
    end
  end

  describe ".row_count" do
    let(:input_file) { "spec/fixtures/files/dfe-schools.zip" }

    it "returns the number of lines in the CSV" do
      expect(described_class.row_count(input_file)).to eq(6) # 1 header + 5 data rows
    end
  end
end
