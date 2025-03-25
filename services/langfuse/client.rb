# frozen_string_literal: true

require "faraday"
require "base64"

require_relative "trace"
require_relative "prompt"

module Services
  module Langfuse
    class Client
      attr_reader :api_key, :secret_key, :adapter

      def initialize(api_key:, secret_key:, adapter: nil)
        @api_key = api_key
        @secret_key = secret_key
        @adapter = adapter || Faraday.default_adapter
      end

      def connection
        @connection ||= Faraday.new(
          url: "https://cloud.langfuse.com/api/public",
          headers: {
            "Authorization" => "Basic #{Base64.strict_encode64("#{api_key}:#{secret_key}")}",
            "Content-Type" => "application/json"
          }
        ) do |faraday|
          faraday.request :json
          faraday.response :json, content_type: /\bjson$/
          faraday.adapter adapter
        end
      end

      def trace
        Services::Langfuse::Trace.new(client: self)
      end

      def prompts
        @prompts ||= Services::Langfuse::Prompt.new(client: self)
      end
    end
  end
end
