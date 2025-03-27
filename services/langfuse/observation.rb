# frozen_string_literal: true

require "securerandom"
require_relative "base"

module Services
  module Langfuse
    class Observation < Base
      attr_accessor :body_params, :trace_id, :type, :id

      TYPES = %w[SPAN GENERATION EVENT].freeze

      def initialize(client:)
        super(client: client)
        @id = SecureRandom.uuid
      end

      def create(trace_id:, type:, request_type: nil, **kwargs)
        raise "Invalid type: #{type}" unless TYPES.include?(type)

        @body_params = kwargs
        @trace_id = trace_id
        @type = type

        payload = {
          batch: [{
            id: id,
            type: request_type || "observation-create",
            timestamp: Time.now.utc.iso8601(3),
            body: {
              **body_params,
              traceId: trace_id,
              type: type,
              id: id
            }
          }]
        }
        client.connection.post("ingestion", payload.to_json)
        self
      end

      def update(**kwargs)
        merged_params = body_params.merge(kwargs)
        create(trace_id: trace_id, type: type, request_type: "observation-update", **merged_params)
      end
    end
  end
end
