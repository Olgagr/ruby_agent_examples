# frozen_string_literal: true

require_relative "langfuse/trace"
require_relative "langfuse/prompt"
module Services
  class LangfuseService
    def trace_create(**kwargs)
      trace = Services::Langfuse::Trace.new
      trace.create(**kwargs)
    end

    def trace_update(trace:, **kwargs)
      trace.update(**kwargs)
    end

    def prompt_fetch(**kwargs)
      prompt = Services::Langfuse::Prompt.new
      prompt.fetch_prompt(**kwargs)
    end

    def prompts_fetch(**kwargs)
      prompt = Services::Langfuse::Prompt.new
      prompt.fetch_prompts(**kwargs)
    end
  end
end
