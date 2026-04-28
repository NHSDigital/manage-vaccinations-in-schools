# frozen_string_literal: true

module MavisCLI
  module Clinics
    class Create < Dry::CLI::Command
      desc "Create a new clinic location"

      argument :name, required: true, desc: "The name of the clinic"
      argument :address_line_1,
               required: true,
               desc: "The line 1 of the address"
      argument :address_town, required: true, desc: "The town of the address"
      argument :address_postcode,
               required: true,
               desc: "The postcode of the address"

      option :ods_code, desc: "The ODS code of the clinic"

      def call(
        name:,
        address_line_1:,
        address_town:,
        address_postcode:,
        ods_code: nil,
        **
      )
        MavisCLI.load_rails

        location =
          Location.create!(
            type: :community_clinic,
            name:,
            address_line_1:,
            address_town:,
            address_postcode:,
            ods_code:
          )

        LocationPositionUpdaterJob.perform_async(location.id)
      end
    end
  end

  register "clinics" do |prefix|
    prefix.register "create", Clinics::Create
  end
end
