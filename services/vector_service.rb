# frozen_string_literal: true

require "qdrant"
require "dotenv"

Dotenv.load

module Services
  class VectorService
    attr_reader :client, :openai_service

    def initialize(openai_service:)
      @client = Qdrant::Client.new(
        url: ENV['QDRANT_URL'],
        api_key: ENV['QDRANT_API_KEY']
      )
      @openai_service = openai_service
    end

    def collections
      client.collections.list
    end

    def ensure_collection(collection_name:)
      collection = collections.dig("result", "collections").find { |c| c["name"] == collection_name }
      return collection if collection

      client.collections.create(
        name: collection_name,
        vectors: { size: 3072, distance: "Cosine" }
      )
    end

    # @param collection_name [String]
    # @param wait [Boolean]
    # @param ordering [String]
    # @param points [{ id: Integer, text: String, role: String }]
    def upsert_points(collection_name:,
                      wait: nil,
                      ordering: nil,
                      points: nil)
      points_to_upsert = points.map do |point|
        embedding = @openai_service.create_embedding(text: point[:text])
        {
          id: point[:id],
          payload: { text: point[:text], role: point[:role] },
          vector: embedding
        }
      end

      client.points.upsert(
        collection_name: collection_name,
        wait: wait,
        ordering: ordering,
        points: points_to_upsert
      )
    end

    def search_points(collection_name:, query:, limit: 5)
      query_embedding = @openai_service.create_embedding(text: query)
      client.points.search(
        collection_name: collection_name,
        limit: limit,
        vector: query_embedding,
        with_payload: true
      )
    end
  end
end
