# frozen_string_literal: true

require_relative "base"

module Services
  module Langfuse
    # Class to manage prompts in Langfuse
    class Prompt < Base
      # Fetches a prompt by name
      # Docs: https://api.reference.langfuse.com/#tag/prompts/GET/api/public/v2/prompts/%7BpromptName%7D
      def fetch_prompt(prompt_name:, version: nil, label: nil)
        response = connection.get("v2/prompts/#{prompt_name}") do |req|
          req.params["version"] = version if version
          req.params["label"] = label if label
        end

        JSON.parse(response.body)
      end

      # Fetches prompts by name, label, tag, limit, from_updated_at, to_updated_at
      # Docs: https://api.reference.langfuse.com/#tag/prompts/GET/api/public/v2/prompts
      def fetch_prompts(name: nil, label: nil, tag: nil, limit: nil, from_updated_at: nil, to_updated_at: nil)
        response = connection.get("v2/prompts") do |req|
          req.params["name"] = name if name
          req.params["label"] = label if label
          req.params["tag"] = tag if tag
          req.params["limit"] = limit if limit
          req.params["fromUpdatedAt"] = from_updated_at if from_updated_at
          req.params["toUpdatedAt"] = to_updated_at if to_updated_at
        end

        JSON.parse(response.body)
      end
    end
  end
end
