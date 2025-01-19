# frozen_string_literal: true

require "minitest/autorun"
require "mocha/minitest"
require_relative "../../services/websearch_service"

module Services
  class WebsearchServiceTest < Minitest::Test
    def setup
      @allowed_domains = [
        { url: "https://www.smashingmagazine.com", description: "Magazine on CSS, JavaScript, front-end, accessibility, UX and design. For developers, designers and front-end engineers." },
        { url: "https://evilmartians.com/chronicles", description: "We've got articles for junior and experienced developers, case studies for startup founders and managers, and thorough technical deep dives into unexpected terrain. No matter where you're coming from, you're certain to gain some insight here, whether it's more practical, or something that really takes you for a ride." }
      ]
      @service = WebsearchService.new(allowed_domains: @allowed_domains, debug_mode: false)
      @openai_service = @service.openai_service
      @firecrawl_service = @service.firecrawl_service
    end

    def test_websearch_needed_returns_true_when_openai_returns_1
      response = { "choices" => [{ "message" => { "content" => "1" } }] }
      @openai_service.expects(:complete).returns(response)

      assert @service.websearch_needed?(user_question: "What is the price of your product?")
    end

    def test_websearch_needed_returns_false_when_openai_returns_0
      response = { "choices" => [{ "message" => { "content" => "0" } }] }
      @openai_service.expects(:complete).returns(response)

      refute @service.websearch_needed?(user_question: "How are you?")
    end

    def test_generate_queries_returns_parsed_queries
      expected_queries = { "queries" => [{ "url" => "example.com", "q" => "test query" }] }
      response = { "choices" => [{ "message" => { "content" => expected_queries.to_json } }] }
      @openai_service.expects(:complete).returns(response)

      result = @service.generate_queries(user_question: "What is the price?")
      assert_equal expected_queries["queries"], result
    end

    def test_web_search_makes_correct_api_call
      queries = [{ "url" => "example.com", "q" => "test query" }]
      mock_connection = mock
      mock_response = mock
      expected_results = { "data" => [{ 
        "url" => "https://example.com/page",
        "title" => "Test Page",
        "description" => "Test description",
        "markdown" => "Test markdown"
      }] }

      @firecrawl_service.expects(:connection).returns(mock_connection)
      mock_connection.expects(:post).with(
        'search',
        {
          "query" => "site:example.com test query",
          "limit" => 5,
          "scrapeOptions" => { formats: ["markdown"] }
        }
      ).returns(mock_response)
      mock_response.expects(:body).returns(expected_results)

      result = @service.web_search(queries: queries, limit: 5)
      assert_equal queries[0]["q"], result[0][:query]
      assert_equal expected_results["data"][0]["url"], result[0][:results][0][:url]
    end

    def test_score_search_results_returns_top_results
      search_results = [
        { 'url' => "example.com/1", 'title' => "title1", 'description' => "desc1", 'markdown' => "markdown1" },
        { 'url' => "example.com/2", 'title' => "title2", 'description' => "desc2", 'markdown' => "markdown2" },
        { 'url' => "example.com/3", 'title' => "title3", 'description' => "desc3", 'markdown' => "markdown3" }
      ]

      responses = [
        { "choices" => [{ "message" => { "content" => { "score" => 0.8 } } }] },
        { "choices" => [{ "message" => { "content" => { "score" => 0.6 } } }] },
        { "choices" => [{ "message" => { "content" => { "score" => 0.9 } } }] }
      ]
      @openai_service.expects(:complete).times(3).returns(*responses)

      results = @service.score_search_results(
        user_question: "test question",
        search_results: search_results
      )

      assert_equal 2, results.length
      assert_equal 0.9, results[0][:score]
      assert_equal 0.8, results[1][:score]
    end

    def test_answer_question_returns_openai_response
      search_results = [{ url: "example.com", content: "test content" }]
      expected_answer = "This is the answer"
      response = { "choices" => [{ "message" => { "content" => expected_answer } }] }
      
      @openai_service.expects(:complete).returns(response)

      result = @service.answer_question(
        search_results: search_results,
        user_question: "test question"
      )

      assert_equal expected_answer, result
    end
  end
end 