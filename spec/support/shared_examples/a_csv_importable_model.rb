# frozen_string_literal: true

shared_examples_for "a CSVImportable model" do
  describe "validations" do
    it { should be_valid }

    it { should validate_presence_of(:csv_filename) }

    context "when the CSV has been removed and data exists" do
      before do
        subject.csv_removed_at = Time.zone.now
        subject.csv_data = "data"
      end

      it { should be_invalid }
    end

    it "raises if processed without updating the statistics" do
      expect {
        subject.update!(processed_at: Time.zone.now, status: :processed)
      }.to raise_error(/Count statistics must be set/)
    end
  end

  describe "#csv=" do
    it "sets the data" do
      expect(subject.csv_data).not_to be_empty
    end

    it "sets the filename" do
      expect(subject.csv_filename).not_to be_empty
    end
  end

  describe "#csv_removed?" do
    it "is false" do
      expect(subject.csv_removed?).to be false
    end

    context "when csv_removed_at is set" do
      before { subject.csv_removed_at = Time.zone.now }

      it "is true" do
        expect(subject.csv_removed?).to be true
      end
    end
  end

  describe "#process!" do
    let(:today) { Time.zone.local(2025, 6, 1) }

    it "sets processed_at" do
      if subject.is_a?(ImmunisationImport)
        expect { travel_to(today) { subject.process! } }.to change(
          subject,
          :processed_at
        ).from(nil).to(today)
      end
    end

    it "resets import issues in team cached counts" do
      team_cached_counts =
        instance_double(TeamCachedCounts, reset_import_issues!: true)

      allow(TeamCachedCounts).to receive(:new).with(subject.team).and_return(
        team_cached_counts
      )

      if subject.is_a?(ImmunisationImport)
        travel_to(today) { subject.process! }
      else
        subject.process!
      end

      expect(TeamCachedCounts).to have_received(:new).with(subject.team)
      expect(team_cached_counts).to have_received(:reset_import_issues!)
    end
  end

  describe "#remove!" do
    let(:today) { Time.zone.local(2020, 1, 1) }

    it "clears the data" do
      expect { subject.remove! }.to change(subject, :csv_data).to(nil)
    end

    it "sets the date/time" do
      expect { travel_to(today) { subject.remove! } }.to change(
        subject,
        :csv_removed_at
      ).from(nil).to(today)
    end
  end
end
