# frozen_string_literal: true

describe GIASImportJob do
  subject(:perform) { described_class.new.perform }

  before do
    allow(GIAS).to receive(:download)
    allow(GIAS).to receive(:check_import)
    allow(GIAS).to receive(:log_import_check_results)
    allow(GIAS).to receive(:import)
  end

  it "runs the import" do
    expect(GIAS).to receive(:download)
    expect(GIAS).to receive(:check_import)
    expect(GIAS).to receive(:log_import_check_results)
    expect(GIAS).to receive(:import)

    perform
  end
end
