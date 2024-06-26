# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::TaskFactory, feature_category: :code_suggestions do
  using RSpec::Parameterized::TableSyntax

  describe '.task' do
    let_it_be(:current_user) { create(:user) }
    let(:file_name) { 'python.py' }
    let(:prefix) { 'some prefix' }
    let(:suffix) { 'some suffix' }
    let(:params) do
      {
        current_file: {
          file_name: file_name,
          content_above_cursor: prefix,
          content_below_cursor: suffix
        }
      }
    end

    subject { described_class.new(current_user, params: params).task }

    shared_examples 'correct task initializer' do
      it 'creates task with model family param' do
        expect(expected_class).to receive(:new).with(**expected_params)

        subject
      end
    end

    it 'calls instructions extractor with expected params' do
      expect(CodeSuggestions::InstructionsExtractor)
        .to receive(:new)
        .with(an_instance_of(CodeSuggestions::FileContent), nil)
        .and_call_original

      subject
    end

    context 'when code completion' do
      let(:expected_class) { ::CodeSuggestions::Tasks::CodeCompletion }
      let(:expected_family) { described_class::VERTEX_AI }
      let(:expected_params) do
        {
          params: params.merge(code_completion_model_family: expected_family),
          unsafe_passthrough_params: {}
        }
      end

      before do
        allow_next_instance_of(CodeSuggestions::InstructionsExtractor) do |instance|
          allow(instance).to receive(:extract).and_return({})
        end
      end

      it_behaves_like 'correct task initializer' do
        let(:expected_family) { described_class::VERTEX_AI }
      end
    end

    context 'when code generation' do
      let(:expected_class) { ::CodeSuggestions::Tasks::CodeGeneration }
      let(:expected_family) { described_class::VERTEX_AI }
      let(:expected_params) do
        {
          params: params.merge(
            code_generation_model_family: expected_family,
            instruction: 'instruction',
            prefix: 'trimmed prefix'
          ),
          unsafe_passthrough_params: {}
        }
      end

      before do
        allow_next_instance_of(CodeSuggestions::InstructionsExtractor) do |instance|
          allow(instance)
            .to receive(:extract)
            .and_return({ instruction: 'instruction', prefix: 'trimmed prefix' })
        end
      end

      it_behaves_like 'correct task initializer' do
        let(:expected_family) { described_class::ANTHROPIC }
      end
    end
  end
end
