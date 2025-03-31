# frozen_string_literal: true

require "date"

require_relative "../services/openai_service"
require_relative "../services/langfuse_service"
require_relative "../services/utils_service"
require_relative "../services/image_service"
require_relative "prompts/summary_prompt"

class SummaryService
  attr_reader :openai_service, :langfuse_service, :image_service

  EXTRACTION_TYPES = [
    { key: "topics", description: "Main subjects covered in the article. Focus here on the headers and all specific topics discussed in the article." },
    { key: "entities", description: "Mentioned people, places, or things mentioned in the article. Skip the links and images." },
    { key: "keywords", description: "Key terms and phrases from the content. You can think of them as hastags that increase searchability of the content for the reader. Example of keyword: OpenAI, Large Language Model, API, Agent, Ruby, Javascript etc.'" },
    { key: "links", description: "Complete list of the links and images mentioned with their 1-sentence description." },
    { key: "resources", description: "Tools, platforms, resources mentioned in the article. Include context of how the resource can be used, what the problem it solves or any note that helps the reader to understand the context of the resource.'" },
    { key: "takeaways", description: "Main points and valuable lessons learned. Focus here on the key takeaways from the article that by themself provide value to the reader (avoid vague and general statements like 'it\'s really important' but provide specific examples and context). You may also present the takeaway in broader context of the article"},
    { key: "context", description: "Background information and setting. Focus here on the general context of the article as if you were explaining it to someone who didn't read the article." }
  ].freeze

  def initialize
    @openai_service = Services::OpenAIService.new
    @langfuse_service = Services::LangfuseService.new
    @image_service = Services::ImageService.new(openai_service: openai_service)
  end

  def summarize(article_content:, output_dir:)
    trace = langfuse_service.trace_create(name: "Summarize article")

    extraction_data = EXTRACTION_TYPES.each_with_object({}) do |extraction_type, memo_obj|
      extracted = extract_information(
        article_content: article_content,
        type: extraction_type[:key],
        description: extraction_type[:description],
        trace_id: trace.id
      )
      memo_obj[extraction_type[:key]] = extracted
      File.write("#{output_dir}/#{extraction_type[:key]}.md", extracted)
      puts "Extracted #{extraction_type[:key]}"
    end

    images_data = image_service.describe_images(text: article_content)

    draft_summary = draft_summary(
      extraction_data: extraction_data,
      article_content: article_content,
      images_data: images_data,
      trace_id: trace.id
    )
    puts "Draft summary prepared"

    critique = critique_summary(
      summary: draft_summary,
      article: article_content,
      context: extraction_data[:context],
      trace_id: trace.id
    )
    puts "Critique prepared"

    finnal_summary(
      draft: draft_summary,
      critique: critique,
      topics: extraction_data[:topics],
      takeaways: extraction_data[:takeaways],
      context: extraction_data[:context],
      trace_id: trace.id,
      images_data: images_data
    )
  end

  def extract_information(article_content:, type:, description:, trace_id:)
    system_message = <<~CONTENT
      Extract #{type}: #{description} from the article content.
      Transform the content into clear, structured yet simple bullet points without formatting except links and images.
      Format link like so: - name: brief description with images and links if the original message contains them.
      Keep full accuracy of the original message.
      Omit any marketing or promotional content like advertisements, sponsorships, or any other content that is not relevant to the #{description}.
    CONTENT

    user_message = <<~CONTENT
      Article content:
      #{article_content}
    CONTENT

    llm_response(
      trace_id: trace_id,
      name: "Extract #{type}",
      messages: [
        { role: "system", content: system_message },
        { role: "user", content: user_message }
      ]
    )
  end

  def draft_summary(extraction_data:, article_content:, images_data:, trace_id:)
    user_message = Prompts::SummaryPrompt.draft_summary_prompt(extraction_data:, article_content:, images_data:)

    llm_response(
      trace_id: trace_id,
      name: "Draft summary",
      messages: [
        { role: "user", content: user_message }
      ]
    )
  end

  def critique_summary(summary:, article:, context:, trace_id:)
    user_message = Prompts::SummaryPrompt.critique_summary_prompt(summary:, article:, context:)

    llm_response(
      trace_id: trace_id,
      name: "Critique summary",
      messages: [
        { role: "user", content: user_message }
      ]
    )
  end

  def finnal_summary(draft:, critique:, topics:, takeaways:, context:, images_data:,trace_id:)
    user_message = Prompts::SummaryPrompt.final_summary_prompt(draft:, critique:, topics:, takeaways:, context:, images_data:)

    llm_response(
      trace_id: trace_id,
      name: "Final summary",
      messages: [
        { role: "user", content: user_message }
      ]
    )
  end

  def llm_response(name:, trace_id:, messages:)
    generation_time_start = DateTime.now.to_s

    response = openai_service.complete(
      messages: messages
    )

    llm_response = response.dig("choices", 0, "message", "content").strip

    generation_time_end = DateTime.now.to_s
    langfuse_service.observation_create(
      trace_id: trace_id,
      name: name,
      type: "GENERATION",
      model: "gpt-4o-mini",
      input: messages.map { |message| message[:content] }.join("\n"),
      output: llm_response,
      startTime: generation_time_start,
      endTime: generation_time_end
    )

    llm_response
  end
end
