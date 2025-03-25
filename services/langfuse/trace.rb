# frozen_string_literal: true

require "securerandom"
require "time"
require_relative "base"

module Services
  module Langfuse
    class Trace < Base
      attr_accessor :body_params, :trace_id

      def initialize(client:)
        super(client: client)
        @trace_id = SecureRandom.uuid
      end

      def create(**kwargs)
        timestamp = Time.now.utc.iso8601(3)
        @body_params = kwargs

        payload = {
          batch: [{
            id: trace_id,
            type: "trace-create",
            timestamp: timestamp,
            body: {
              **body_params,
              id: trace_id,
              timestamp: timestamp
            }
          }]
        }

        client.connection.post("ingestion", payload.to_json)
        self
      end

      def update(**kwargs)
        merged_params = body_params.merge(kwargs)
        create(**merged_params)
      end
    end
  end
end
