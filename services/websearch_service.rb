# frozen_string_literal: true

require "dotenv"
require "faraday"
require_relative "./openai_service"
require_relative "./firecrawl_service"
require_relative "../prompts/website_prompt"

Dotenv.load

module Services
  class WebsearchService
    include Prompts::WebsitePrompt

    attr_reader :debug_mode, :allowed_domains, :openai_service, :firecrawl_service
    
    def initialize(allowed_domains:, debug_mode:)
      @openai_service = Services::OpenAIService.new
      @firecrawl_service = Services::FirecrawlService.new
      @allowed_domains = allowed_domains
      @debug_mode = debug_mode
    end

    def websearch_needed?(user_message:)
      messages = [
        { role: 'system', content: use_websearch },
        { role: 'user', content: user_message }
      ]
      response = openai_service.complete(messages:, model: 'gpt-4o')
      response_message = response.dig("choices", 0, "message", "content")

      debug_step(step_name: "IS WEBSEARCH_NEEDED?", step_description: response_message.to_i == 1)

      response_message.to_i == 1
    end

    def generate_queries(user_message:)
      messages = [
        { role: "system", content: pick_domains_for_user_query(resources: allowed_domains) },
        { role: "user", content: user_message }
      ]
      response = openai_service.complete(messages:, model: 'gpt-4o')
      response_message = JSON.parse(response.dig("choices", 0, "message", "content"))

      debug_step(step_name: "GENERATED QUERIES", step_description: response_message["queries"])

      response_message["queries"]
    end

    def web_search(queries:, limit:)
      queries.map do |item|
        host_name = URI(item['url'].start_with?('https://') ? item['url'] : "https://#{item['url']}").hostname
        site_query = "site:#{host_name} #{item['q']}"
        
        conn = firecrawl_service.connection
        payload = {
          "query" => site_query,
          "limit" => limit,
          "scrapeOptions" => {
            "formats": ["markdown"]
          }
        }
        begin
          response = conn.post('search', payload)
          results = response.body["data"]
          {
            query: item["q"],
            results: results.map do |r|
              {
                url: r["url"],
                title: r["title"],
                description: r["description"],
                markdown: r["markdown"]
              }
            end
          }
        rescue Faraday::Error => e
          puts "The /search Firecrowl error was raised.\nStatus: #{e.response_status}\nBody: #{e.e.response_body}"
        end
      end
    end

    private

    def debug_step(step_name:, step_description:)
      puts "#{step_name}\n#{step_description}" if debug_mode
    end

  end
end