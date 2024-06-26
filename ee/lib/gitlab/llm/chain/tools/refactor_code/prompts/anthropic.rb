# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module RefactorCode
          module Prompts
            class Anthropic
              def self.prompt(variables)
                base_prompt = Utils::Prompt.no_role_text(
                  ::Gitlab::Llm::Chain::Tools::RefactorCode::Executor::PROMPT_TEMPLATE, variables
                )
                {
                  prompt: "\n\nHuman: #{base_prompt}\n\nAssistant:",
                  options: {}
                }
              end
            end
          end
        end
      end
    end
  end
end
