# frozen_string_literal: true

require_relative "openai_service"
require_relative "../prompts/image_prompt"

module Services
  class ImageService
    include Prompts::ImagePrompt

    attr_reader :openai_service

    def initialize(openai_service: Services::OpenAIService.new)
      @openai_service = openai_service
    end

    def describe_images(text:)
      images_data = extract_images_from_text(text: text)
      return [] unless images_data.any?

      images_context = image_context(images: images_data, text: text)
      images_visual_description = images_data.map do |image_data|
        image_visual_description(image: image_data)
      end

      images_data.map do |image_data|
        image_context = images_context["images"].find { |context| context["name"] == image_data[:name] }
        image_visual_description = images_visual_description.find { |description| description["name"] == image_data[:name] }
        image_data[:context] = image_context["context"]
        image_data[:description] = image_visual_description["preview"]
        image_data
      end
    end

    def extract_images_from_text(text:, image_regex: /!\[([^\]]*)\]\(([^)]+)\)/)
      images_matches = text.scan(image_regex)

      threads = images_matches.map do |(alt, url)|
        Thread.new(alt, url) do |alt_value, url_value|
          name = url.split("/").last || ""
          response = Faraday.get(url)
          raise ImageFetchError, "Failed to fetch image from #{url}" if response.status != 200

          base64_image = Base64.strict_encode64(response.body)
          {
            alt: alt_value,
            url: url_value,
            name:,
            context: "",
            description: "",
            base64: "data:image/png;base64,#{base64_image}"
          }
        rescue ImageFetchError => e
          puts "Error fetching image from #{url}: #{e.message}"
          nil
        end
      end

      threads.map(&:value).compact
    end

    def image_context(images:, text:, model: "gpt-4o-mini")
      response = openai_service.complete(
        messages: [
          { role: "system", content: image_context_prompt(images:) },
          { role: "user", content: "Here is the text with the images: #{text}" }
        ],
        model:
      )

      JSON.parse(response.dig("choices", 0, "message", "content"))
    end

    def image_visual_description(image:, model: "gpt-4o-mini")
      user_message_content = [
        {
          type: "image_url",
          image_url: { url: image[:url] }
        },
        {
          type: "text",
          text: "Describe the image #{image[:name]} concisely. Focus on the main elements and overall composition. Return the result in JSON format with only 'name' and 'preview' properties."
        }
      ]

      response = openai_service.complete(
        messages: [
          { role: "system", content: image_visual_description_prompt },
          { role: "user", content: user_message_content }
        ],
        model: model
      )

      JSON.parse(response.dig("choices", 0, "message", "content"))
    end

    def refined_image_description(image:, image_context:, image_visual_description:)
      user_message = {
        content: [
          {
            type: "image_url",
            image_url: { url: image[:url] }
          },
          {
            type: "text",
            text: <<~PROMPT
              Write a description of the image #{image[:name]}.
              I have some <context>#{image_context}</context> that should be useful for understanding the image in a better way.
              An initial visual description of the image is: <description>#{image_visual_description}</description>.
              A good description briefly describes what is on the image, and uses the context to make it more relevant to the text in which the image is mentioned.
              Return only the description text, nothing else.
            PROMPT
          }
        ]
      }

      response = openai_service.complete(
        messages: [
          { role: "user", content: user_message }
        ],
        model:
      )

      JSON.parse(response.dig("choices", 0, "message", "content"))
    end
  end
end
