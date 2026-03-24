# frozen_string_literal: true

describe AddressHelper do
  let(:location) do
    create(
      :gias_school,
      name: "School of Politics",
      address_line_1: "10 Downing Street",
      address_town: "London",
      address_postcode: "SW1A 1AA"
    )
  end

  describe "#format_address_multi_line" do
    subject(:formatted_string) { helper.format_address_multi_line(location) }

    it { should eq("10 Downing Street<br>London<br>SW1A 1AA") }
  end

  describe "#format_address_single_line" do
    subject(:formatted_string) { helper.format_address_single_line(location) }

    it { should eq("10 Downing Street, London, SW1A 1AA") }
  end
end
