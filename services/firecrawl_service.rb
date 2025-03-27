# frozen_string_literal: true

require "faraday"

module Services
  class FirecrawlService
    def connection
      Faraday.new(
        url: "https://api.firecrawl.dev/v1",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['FIRECRAWL_API_KEY']}"
        }
      ) do |faraday|
        faraday.response :raise_error
      end
    end

    def scrape(url:, formats: ["markdown"], **kwargs)
      response = connection.post("scrape") do |req|
        req.body = { url: url, formats: formats, **kwargs }.to_json
      end
      JSON.parse(response.body)["data"]
    end
  end
end
