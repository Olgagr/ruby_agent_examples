# frozen_string_literal: true

require "openai"
require "dotenv"

Dotenv.load

module Services
  # This class is responsible for interacting with the OpenAI API
  class OpenAIService
    IMAGE_MAX_DIMENSION = 2048
    IMAGE_SCALE_SIZE = 768

    attr_reader :client

    def initialize
      @client = OpenAI::Client.new(
        access_token: ENV["OPENAI_API_KEY"],
        log_errors: true
      )
    end

    def rough_token_count(message:)
      OpenAI.rough_token_count(message)
    end

    def complete(messages:, model: "gpt-4o-mini", temperature: 0.5, stream: nil)
      client.chat(parameters: {
                    model: model,
                    messages: messages,
                    temperature: temperature,
                    stream: stream
                  })
    end

    def generate_summarization(previous_summary:, user_message:, assistant_response:) # rubocop:disable Metrics/MethodLength
      system_message = {
        role: "system",
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

      complete(model: "gpt-4o-mini", messages: [system_message])
    end

    def create_embedding(text:, model: "text-embedding-3-large")
      response = client.embeddings(
        parameters: {
          model: model,
          input: text
        }
      )

      response.dig("data", 0, "embedding")
    end

    def transcribe(file_path:, language: "en")
      response = client.audio.transcribe(
        parameters: {
          file: File.open(file_path, "rb"),
          model: "whisper-1",
          language: language
        }
      )

      response["text"]
    end

    def generate_image(prompt:, size: "1024x1024", model: "dall-e-3", quality: "standard")
      response = client.images.generate(
        parameters: {
          prompt: prompt,
          size: size,
          model: model,
          quality: quality
        }
      )

      response["data"].first["url"]
    end

    def calculate_image_tokens(width, height, detail)
      token_cost = 0

      # For low detail, return fixed cost
      if detail == 'low'
        token_cost += 85
        return token_cost
      end

      # Convert to float for calculations
      width = width.to_f
      height = height.to_f

      # Resize to fit within IMAGE_MAX_DIMENSION x IMAGE_MAX_DIMENSION
      if width > IMAGE_MAX_DIMENSION || height > IMAGE_MAX_DIMENSION
        aspect_ratio = width / height
        if aspect_ratio > 1
          width = IMAGE_MAX_DIMENSION
          height = (IMAGE_MAX_DIMENSION / aspect_ratio).round
        else
          height = IMAGE_MAX_DIMENSION
          width = (IMAGE_MAX_DIMENSION * aspect_ratio).round
        end
      end

      # Scale the shortest side to IMAGE_SCALE_SIZE
      if width >= height && height > IMAGE_SCALE_SIZE
        width = ((IMAGE_SCALE_SIZE / height) * width).round
        height = IMAGE_SCALE_SIZE
      elsif height > width && width > IMAGE_SCALE_SIZE
        height = ((IMAGE_SCALE_SIZE / width) * height).round
        width = IMAGE_SCALE_SIZE
      end

      # Calculate the number of 512px squares
      num_squares = (width / 512.0).ceil * (height / 512.0).ceil

      # Calculate the token cost
      token_cost += (num_squares * 170) + 85

      token_cost
    end
  end
end
