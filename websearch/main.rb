# frozen_string_literal: true

require "bundler/setup"

require_relative "../services/openai_service"
require_relative "../services/websearch_service"

allowed_domains = [
  { url: "https://www.smashingmagazine.com", description: "Magazine on CSS, JavaScript, front-end, accessibility, UX and design. For developers, designers and front-end engineers." },
  { url: "https://evilmartians.com/chronicles", description: "We've got articles for junior and experienced developers, case studies for startup founders and managers, and thorough technical deep dives into unexpected terrain. No matter where you're coming from, you're certain to gain some insight here, whether it's more practical, or something that really takes you for a ride." }
]

if __FILE__ == $PROGRAM_NAME
  websearch_service = Services::WebsearchService.new(allowed_domains: allowed_domains, debug_mode: true)

  # loop do
    puts "How can I help you today? (type 'exit' to quit)"

    user_question = gets.chomp
    # do we need to websearch to respond user prompt or can model use it's inner knowledge
    is_websearch_needed = websearch_service.websearch_needed?(user_question:)

    if is_websearch_needed
      # pick domains and generate queries that match user prompt
      generated_queries = websearch_service.generate_queries(user_question:)

      if generated_queries.size > 0
        # 1. Take a generated query
        # 2. Search it on the selected website
        # 3. Returned scrapped website that matches the query
        # {
        #   url:
        #   title:
        #   description:
        #   markdown
        # }[]
        search_results = websearch_service.web_search(queries: generated_queries, limit: 1)
        
        # Takes search results, scores their relevance and returns 2 the highest best results for each URL
        # {
        #   url:
        #   title:
        #   description:
        #   markdown:
        #   score:
        # }[]
        scored_search_results = websearch_service.score_search_results(user_question:, search_results:)
        answer = websearch_service.answer_question(search_results: scored_search_results)
        
        puts answer
      end
    end
  # end
end

