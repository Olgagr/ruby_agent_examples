# frozen_string_literal: true

require "erb"

module Prompts
  module SummaryPrompt
    def self.draft_summary_prompt(article_content:, extraction_data:, images_data:)
      template = %q(
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
        <% extraction_data.map do |key, value| %>
          <<%= key %>><%= value %></<%= key %>>
        <% end %>

        <% if images_data.any? %>
          Here are the images descriptions:
          <images>
          <% images_data.map do |image_data| %>
            <image>
              Name: <%= image_data[:name] %>
              Context: <%= image_data[:context] %>
              Description: <%= image_data[:description] %>
            </image>
          <% end %>
          <images>
        <% end %>

        <original_article_content>
          <%= article_content %>
        </original_article_content>

        Return only the summary, no other text.
      ).gsub(/^  /, "")

      ERB.new(template).result(binding)
    end

    def self.critique_summary_prompt(summary:, article:, context:)
      template = %q(
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
        </analysis_parameters>

        <original_article><%= article %></original_article>

        <context desc="It may help you to understand the article better."><%= context %></context>

        <compressed_version><%= summary %></compressed_version>

        RESPONSE REQUIREMENTS:
        - Identify ALL deviations, regardless of scale
        - Report exact location of each discrepancy
        - Provide specific correction requirements
        - Document missing elements precisely
        - Mark any unauthorized additions

        Your task: Execute comprehensive analysis of compressed version against source material. Document every deviation. No exceptions permitted.
        Return only the critique, no other text.
      ).gsub(/^  /, "")

      ERB.new(template).result(binding)
    end

    def self.final_summary_prompt(draft:, critique:, topics:, takeaways:, context:, images_data:)
      template = %q(
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

        <draft><%= draft %></draft>
        <topics><%= topics %></topics>
        <takeaways><%= takeaways %></takeaways>
        <critique note="This is important, as it was created based on the initial draft of the compressed version. Consider it before you start writing the final compressed version"><%= critique %></critique>
        <context><%= context %></context>
        <images_description>
        <% images_data.map do |image_data| %>
          <image>
            <image_name><%= image_data[:name] %></image_name>
            <image_context><%= image_data[:context] %></image_context>
            <image_description><%= image_data[:description] %></image_description>
          </image>
        <% end %>
        </images_description>

        Return only the final summary on the markdown format, no other text.
      ).gsub(/^  /, "")

      ERB.new(template).result(binding)
    end
  end
end
