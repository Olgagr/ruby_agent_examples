# frozen_string_literal: true
require "bundler/setup"

require_relative "chat_thread"
require_relative "../services/langfuse_service"

if __FILE__ == $PROGRAM_NAME
  thread = ChatThread.new
  langfuse_service = Services::LangfuseService.new
  puts "Chat started (type 'exit' to quit)"

  loop do
    user_message = gets.chomp
    break if user_message == "exit"

    trace = langfuse_service.trace_create(
      name: user_message,
      input: user_message
    )

    response = thread.chat(user_message)
    puts response.dig("choices", 0, "message", "content")
    langfuse_service.trace_update(
      trace: trace,
      output: response.dig("choices", 0, "message", "content")
    )
  end

  puts "Chat ended"
end
