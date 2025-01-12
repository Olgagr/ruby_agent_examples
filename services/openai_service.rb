# frozen_string_literal: true

require "openai"
require "dotenv"

Dotenv.load

module Services
  class OpenAIService
    def initialize
      @client = OpenAI::Client.new(
        access_token: ENV["OPENAI_API_KEY"],
        log_errors: true
      )
    end

    def complete(model: 'gpt-4o-mini', messages:, temperature: 0.5, stream: nil)
      @client.chat(parameters: {
        model: model,
        messages: messages,
        temperature: temperature,
        stream: stream
      })
    end

    def generate_summarization(previous_summary:, user_message:, assistant_response:)
      system_message = {
        role: 'system',
        content: <<~CONTENT
          Please summarize the following conversation in a concise manner, incorporating the previous summary if available:
          <previous_summary>
            #{previous_summary ? previous_summary : "No previous summary."}
          </previous_summary>
          <current_turn>
            USER: #{user_message}
            ASSISTANT: #{assistant_response}
          </current_turn>
        CONTENT
      }

      complete(model: 'gpt-4o-mini', messages: [system_message])
    end
  end
end
