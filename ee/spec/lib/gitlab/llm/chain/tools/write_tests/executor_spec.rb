# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::WriteTests::Executor, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let(:options) { { input: 'input' } }
  let(:command) { nil }

  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: nil, resource: nil, ai_request: ai_request_double,
      current_file: { file_name: 'test.py', selected_text: 'selected text' }
    )
  end

  subject(:tool) { described_class.new(context: context, options: options, command: command) }

  describe '#name' do
    it 'returns tool name' do
      expect(described_class::NAME).to eq('WriteTests')
    end

    it 'returns tool human name' do
      expect(described_class::HUMAN_NAME).to eq('Write Tests')
    end
  end

  describe '#description' do
    it 'returns tool description' do
      desc = 'Useful tool to write tests for source code.'

      expect(described_class::DESCRIPTION).to include(desc)
    end
  end

  describe '#execute' do
    shared_examples_for 'prompt caller' do
      let(:prompt_class) { Gitlab::Llm::Chain::Tools::WriteTests::Prompts::Anthropic }

      before do
        allow(ai_request_double).to receive(:request).and_return('response')
        allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)
      end

      it 'calls prompt with correct params' do
        expect(prompt_class).to receive(:prompt).with(expected_params)

        tool.execute
      end
    end

    context 'when context is authorized' do
      before do
        allow(Gitlab::Llm::Chain::Utils::Authorizer).to receive(:context_allowed?)
          .and_return(true)
      end

      it_behaves_like 'prompt caller' do
        let(:expected_params) do
          {
            input: 'input',
            selected_text: 'selected text',
            language_info: 'The code is written in Python and stored as test.py'
          }
        end
      end

      context 'when slash command is used' do
        let(:command_prompt_options) { { input: 'command instruction' } }
        let(:command) { instance_double(Gitlab::Llm::Chain::SlashCommand, prompt_options: command_prompt_options) }
        let(:options) { { input: '/tests something' } }

        it_behaves_like 'prompt caller' do
          let(:expected_params) do
            {
              input: 'command instruction',
              selected_text: 'selected text',
              language_info: 'The code is written in Python and stored as test.py'
            }
          end
        end

        it 'builds the expected prompt' do
          allow(tool).to receive(:provider_prompt_class)
            .and_return(Gitlab::Llm::Chain::Tools::WriteTests::Prompts::Anthropic)

          expected_prompt = <<~PROMPT.chomp


            Human: You are a software developer.
            You can write new tests.
            The code is written in Python and stored as test.py
            Here is the code user selected:

            <code>
              selected text
            </code>

            The generated code should be formatted in markdown.
            command instruction

            Assistant:
          PROMPT

          expect(tool.prompt[:prompt]).to eq(expected_prompt)
        end
      end

      context 'when response is successful' do
        it 'returns success answer' do
          allow(tool).to receive(:request).and_return('response')

          expect(tool.execute.content).to eq('response')
        end
      end

      context 'when error is raised during a request' do
        it 'returns error answer' do
          allow(tool).to receive(:request).and_raise(StandardError)

          expect(tool.execute.content).to eq('Unexpected error')
        end
      end
    end

    context 'when context is not authorized' do
      before do
        allow(Gitlab::Llm::Chain::Utils::Authorizer).to receive_message_chain(:context_authorized, :allowed?)
          .and_return(false)
      end

      it 'returns error answer' do
        allow(tool).to receive(:authorize).and_return(false)

        expect(tool.execute.content)
          .to eq('I am sorry, I am unable to find what you are looking for.')
      end
    end

    context 'when code tool was already used' do
      before do
        context.tools_used << described_class
      end

      it 'returns already used answer' do
        allow(tool).to receive(:request).and_return('response')

        expect(tool.execute.content).to eq('You already have the answer from WriteTests tool, read carefully.')
      end
    end
  end
end
