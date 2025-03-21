# frozen_string_literal: true

require "faraday"
require "base64"
require "dotenv"

Dotenv.load

module Services
  module Langfuse
    class Base
      attr_reader :connection

      def initialize
        @connection = Faraday.new(
          url: "https://cloud.langfuse.com/api/public",
          headers: {
            "Authorization" => "Basic #{Base64.strict_encode64("#{ENV['LANGFUSE_PUBLIC_API_KEY']}:#{ENV['LANGFUSE_SECRET_API_KEY']}")}",
            "Content-Type" => "application/json"
          }
        )
      end
    end
  end
end 