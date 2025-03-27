# frozen_string_literal: true

require "dotenv"

Dotenv.load

require_relative "langfuse/client"

module Services
  class LangfuseService
    attr_reader :client

    def initialize
      @client = Services::Langfuse::Client.new(
        api_key: ENV["LANGFUSE_PUBLIC_API_KEY"],
        secret_key: ENV["LANGFUSE_SECRET_API_KEY"]
      )
    end

    def trace_create(**kwargs)
      client.trace.create(**kwargs)
    end

    def trace_update(trace:, **kwargs)
      trace.update(**kwargs)
    end

    def prompt_fetch(**kwargs)
      client.prompts.fetch_prompt(**kwargs)
    end

    def prompts_fetch(**kwargs)
      client.prompts.fetch_prompts(**kwargs)
    end

    def observation_create(**kwargs)
      client.observation.create(**kwargs)
    end

    def observation_update(observation:, **kwargs)
      observation.update(**kwargs)
    end
  end
end
