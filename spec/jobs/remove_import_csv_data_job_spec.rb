# frozen_string_literal: true

describe RemoveImportCSVDataJob do
  describe "#perform" do
    subject(:perform) { described_class.new.perform }

    %w[class_import cohort_import immunisation_import].each do |factory_name|
      context "for #{factory_name.camelize}" do
        let(:to_remove) do
          create(factory_name, created_at: Time.zone.now - 90.days)
        end
        let(:already_removed) { create(factory_name, :csv_removed) }
        let(:not_to_remove) { create(factory_name) }

        it "removes the imports older than 30 days" do
          expect { perform }.to change { to_remove.reload.csv_removed? }.from(
            false
          ).to(true)
        end

        it "doesn't change already removed imports" do
          expect { perform }.not_to change(already_removed, :csv_removed_at)
        end

        it "doesn't remove a new import" do
          expect { perform }.not_to change(not_to_remove, :csv_removed?).from(
            false
          )
        end
      end
    end
  end
end
