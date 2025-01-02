require_relative "../services/openai_service"

class ChatThread
  def initialize
    @openai_service = OpenAIService.new
    @previous_summary  = nil
  end

  def chat(user_message)
    system_prompt = generate_system_prompt
    response = @openai_service.complete(messages: [
      system_prompt,
      {
        role: "user",
        content: user_message
      }
    ])

    summary_response = @openai_service.generate_summarization(
      previous_summary: @previous_summary,
      user_message: user_message, 
      assistant_response: response.dig("choices", 0, "message", "content")
    )

    @previous_summary = summary_response.dig("choices", 0, "message", "content")

    response
  end

  def generate_system_prompt
    previous_summary = <<~PREVIOUS_SUMMARY if @previous_summary
      Here is a previous conversation summary: 
        <previous_summary>
          #{@previous_summary}
        </previous_summary>
    PREVIOUS_SUMMARY

    {
      role: "system",
      content: <<~CONTENT
        You're a helpful assistant who speaks using aa few words as possible.
        #{previous_summary}
        Let's chat
      CONTENT
    } 
  end
end