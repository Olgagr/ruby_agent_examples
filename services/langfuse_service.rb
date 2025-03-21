# frozen_string_literal: true

require_relative "langfuse/trace"

module Services
  class LangfuseService
    def trace_create(**kwargs)
      trace = Services::Langfuse::Trace.new
      trace.create(**kwargs)
    end

    def trace_update(trace:, **kwargs)
      trace.update(**kwargs)
    end
  end
end
