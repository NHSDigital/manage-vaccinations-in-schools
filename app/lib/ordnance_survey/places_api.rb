# frozen_string_literal: true

module OrdnanceSurvey
  class PlacesAPI
    def self.find(...) = new.find(...)

    def initialize
      @api_key = Settings.ordnance_survey.api_key
      @base_url = "https://api.os.uk"
    end

    def find(query, max_results: 1, output_srs: "EPSG:4326")
      params = { query:, maxresults: max_results, output_srs:, format: "json" }
      response = connection.get("/search/places/v1/find", params)
      response.body.deep_transform_keys(&:downcase).deep_symbolize_keys
    end

    private

    def connection
      @connection ||=
        Faraday.new(url: @base_url) do |f|
          f.request :url_encoded
          f.headers["Key"] = @api_key
          f.response :logger if Rails.env.development?
          f.response :json
          f.response :raise_error
        end
    end
  end
end
