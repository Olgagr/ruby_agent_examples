# frozen_string_literal: true

require "faraday"
require "zip"
require "base64"
module Services
  module UtilsService
    class ImageFetchError < StandardError; end

    def self.fetch_and_unzip(url:, destination:)
      # Download the file using Faraday
      response = Faraday.get(url) do |req|
        req.options.timeout = 30
        req.options.open_timeout = 10
      end

      # Create a Zip::File instance from the response body
      Zip::File.open_buffer(response.body) do |zip_file|
        zip_file.each do |entry|
          puts "Extracting #{entry.name}"
          unless File.exist?(entry.name)
            FileUtils.mkdir_p(File.dirname("#{destination}/#{entry.name}"))
            entry.extract("#{destination}/#{entry.name}") { true }
          end
        end
      end
    end
  end
end
