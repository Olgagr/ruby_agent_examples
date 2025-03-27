# frozen_string_literal: true

require "date"

require_relative "../services/openai_service"
require_relative "../services/langfuse_service"

class SummaryService
  attr_reader :openai_service, :langfuse_service

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

    draft_summary = draft_summary(
      extraction_data: extraction_data,
      article_content: article_content,
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
      trace_id: trace.id
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

  def draft_summary(extraction_data:, article_content:, trace_id:)
    user_message = <<~CONTENT
      Draft summary of the article based on the following extraction data and the original article content.
      Write in markdown format, incorporating all images and links within the content. The summary must:

      Write in the language of the original article, ensuring every crucial element from the original is included while:
      - Stay driven and motivated, ensuring you never miss the details needed to understand the article
      - Always preserve original headers and subheaders
      - Mimic the original author's writing style, tone, expressions and voice
      - Presenting ALL main points with complete context and explanation
      - Following the original structure and flow without omitting any details
      - Including every topic, subtopic, and insight comprehensively
      - Preserving the author's writing characteristics and perspective
      - Ensuring readers can fully grasp the subject matter without prior knowledge
      - If you encounter a code block, keep it as is.

      Before writing, examine the original to capture:
      * Writing style elements
      * All images, links, code blocks and vimeo videos from the original article
      * Include examples, quotes and keypoints from the original article
      * Language patterns and tone
      * Rhetorical approaches
      * Argument presentation methods

      Note: You're forbidden to use high-emotional language such as "revolutionary", "innovative", "powerful", "amazing", "game-changer", "breakthrough", "dive in", "delve in", "dive deeper" etc.

      Reference and integrate ALL of the following elements in markdown format:
      #{extraction_data.map { |key, value| "<#{key}>#{value}</#{key}>" }.join("\n")}

      <original_article_content>
      #{article_content}
      </original_article_content>

      Return only the summary, no other text.
    CONTENT

    llm_response(
      trace_id: trace_id,
      name: "Draft summary",
      messages: [
        { role: "user", content: user_message }
      ]
    )
  end

  def critique_summary(summary:, article:, context:, trace_id:)
    user_message = <<~CONTENT
      Analyze the provided compressed version of the article critically, focusing solely on its factual accuracy, structure and comprehensiveness in relation to the given context.

      <analysis_parameters>
      PRIMARY OBJECTIVE: Compare compressed version against original content with 100% precision requirement.

      VERIFICATION PROTOCOL:
      - Each statement must match source material precisely
      - Every concept requires direct source validation
      - No interpretations or assumptions permitted
      - Markdown formatting must be exactly preserved
      - All technical information must maintain complete accuracy

      CRITICAL EVALUATION POINTS:
      1. Statement-level verification against source
      2. Technical accuracy assessment
      3. Format compliance check
      4. Link and reference validation
      5. Image placement verification
      6. Conceptual completeness check

      <original_article>#{article}</original_article>

      <context desc="It may help you to understand the article better.">#{context}</context>

      <compressed_version>#{summary}</compressed_version>

      RESPONSE REQUIREMENTS:
      - Identify ALL deviations, regardless of scale
      - Report exact location of each discrepancy
      - Provide specific correction requirements
      - Document missing elements precisely
      - Mark any unauthorized additions

      Your task: Execute comprehensive analysis of compressed version against source material. Document every deviation. No exceptions permitted.
      Return only the critique, no other text.
    CONTENT

    llm_response(
      trace_id: trace_id,
      name: "Critique summary",
      messages: [
        { role: "user", content: user_message }
      ]
    )
  end

  def finnal_summary(draft:, critique:, topics:, takeaways:, context:, trace_id:)
    user_message = <<~CONTENT
      Create a final compressed version of the article that starts with an initial concise overview, then covers all the key topics using available knowledge in a condensed manner, and concludes with essential insights and final remarks. 
      Consider the critique provided and address any issues it raises.

      Important: Include relevant links and images from the context in markdown format. Do NOT include any links or images that are not explicitly mentioned in the context.
      Note: You're forbidden to use high-emotional language such as "revolutionary", "innovative", "powerful", "amazing", "game-changer", "breakthrough", "dive in", "delve in", "dive deeper" etc.

      Requirement: Use the language of the draft.

      Guidelines for compression:
      - Maintain the core message and key points of the original article
      - Always preserve original headers and subheaders
      - Ensure that images, links and videos are present in your response
      - Eliminate redundancies and non-essential details
      - Use concise language and sentence structures
      - Preserve the original article's tone and style in a condensed form

      <draft>#{draft}</draft>
      <topics>#{topics}</topics>
      <takeaways>#{takeaways}</takeaways>
      <critique note="This is important, as it was created based on the initial draft of the compressed version. Consider it before you start writing the final compressed version">#{critique}</critique>
      <context>#{context}</context>

      Return only the final summary on the markdown format, no other text.
    CONTENT

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
