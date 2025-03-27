# frozen_string_literal: true

require "bundler/setup"
require "fileutils"

require_relative "../services/openai_service"
require_relative "../services/websearch_service"
require_relative "summary_service"

if __FILE__ == $PROGRAM_NAME
  puts "Summary started"
  firecrawl_service = Services::FirecrawlService.new
  summary_service = SummaryService.new

  # get first argument as article URL
  article_url = ARGV[0]
  puts "Article URL: #{article_url}"

  # get article content
  article_content = firecrawl_service.scrape(url: article_url)

  # # save article content to file
  files_url = "#{__dir__}/extracted"
  FileUtils.mkdir_p(files_url) unless File.exist?(files_url)
  File.write("#{files_url}/article.md", article_content["markdown"]) if article_content

  puts "Article content saved to article.md"

  # read article from the file
  article_content = File.read("#{files_url}/article.md")

  summary = summary_service.summarize(article_content: article_content, output_dir: files_url)
  File.write("#{files_url}/summary.md", summary)
  puts "Summary saved to #{files_url}/summary.md"
end
