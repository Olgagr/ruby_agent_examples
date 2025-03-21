# frozen_string_literal: true

require 'openai'
require 'dotenv'

Dotenv.load

module Services
  # This class is responsible for interacting with the OpenAI API
  class OpenAIService
    def initialize
      @client = OpenAI::Client.new(
        access_token: ENV['OPENAI_API_KEY'],
        log_errors: true
      )
    end

    # def trace_session(session_id:, session_name: nil, session_path: nil)
    #   headers = { 'Helicone-Session-Id' => session_id }
    #   headers['Helicone-Session-Name'] = session_name if session_name
    #   headers['Helicone-Session-Path'] = session_path if session_path
    #   @client.add_headers(headers)
    # end

    def rough_token_count(message:)
      OpenAI.rough_token_count(message)
    end

    def complete(messages:, model: 'gpt-4o-mini', temperature: 0.5, stream: nil)
      @client.chat(parameters: {
                     model: model,
                     messages: messages,
                     temperature: temperature,
                     stream: stream
                   })
    end

    def generate_summarization(previous_summary:, user_message:, assistant_response:) # rubocop:disable Metrics/MethodLength
      system_message = {
        role: 'system',
        content: <<~CONTENT
          Please summarize the following conversation in a concise manner, incorporating the previous summary if available:
          <previous_summary>
            #{previous_summary || 'No previous summary.'}
          </previous_summary>
          <current_turn>
            USER: #{user_message}
            ASSISTANT: #{assistant_response}
          </current_turn>
        CONTENT
      }

      complete(model: 'gpt-4o-mini', messages: [system_message])
    end

    def create_embedding(text:, model: 'text-embedding-3-large')
      response = @client.embeddings(parameters: {
                                      model: model,
                                      input: text
                                    })

      response.dig('data', 0, 'embedding')
    end
  end
end
