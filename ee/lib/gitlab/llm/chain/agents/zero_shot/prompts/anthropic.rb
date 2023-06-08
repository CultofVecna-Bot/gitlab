# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        module ZeroShot
          module Prompts
            class Anthropic < Base
              def self.prompt(options)
                "\n\nHuman: #{super(options)}\n\nAssistant:"
              end
            end
          end
        end
      end
    end
  end
end
