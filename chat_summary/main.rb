# frozen_string_literal: true
require "bundler/setup"

require_relative "chat_thread"

if __FILE__ == $PROGRAM_NAME
  thread = ChatThread.new
  puts "Chat started (type 'exit' to quit)"

  loop do
    user_message = gets.chomp
    break if user_message == "exit"

    response = thread.chat(user_message)
    puts response.dig("choices", 0, "message", "content")
  end

  puts "Chat ended"
end

