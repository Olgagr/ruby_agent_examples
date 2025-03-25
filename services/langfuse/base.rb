# frozen_string_literal: true

require_relative "client"

module Services
  module Langfuse
    class Base
      attr_reader :client

      def initialize(client:)
        @client = client
      end
    end
  end
end
