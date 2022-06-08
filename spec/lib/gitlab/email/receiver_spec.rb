# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Email::Receiver do
  include_context :email_shared_context

  let(:metric_transaction) { instance_double(Gitlab::Metrics::WebTransaction) }

  shared_examples 'successful receive' do
    let_it_be(:project) { create(:project) }

    let(:handler) { double(:handler, project: project, execute: true, metrics_event: nil, metrics_params: nil) }
    let(:client_id) { 'email/jake@example.com' }

    it 'correctly finds the mail key' do
      expect(Gitlab::Email::Handler).to receive(:for).with(an_instance_of(Mail::Message), 'gitlabhq/gitlabhq+auth_token').and_return(handler)

      receiver.execute
    end

    it 'adds metric event' do
      allow(receiver).to receive(:handler).and_return(handler)

      expect(::Gitlab::Metrics::BackgroundTransaction).to receive(:current).and_return(metric_transaction)
      expect(metric_transaction).to receive(:add_event).with(handler.metrics_event, handler.metrics_params)

      receiver.execute
    end

    it 'returns valid metadata' do
      allow(receiver).to receive(:handler).and_return(handler)

      metadata = receiver.mail_metadata

      expect(metadata.keys).to match_array(%i(mail_uid from_address to_address mail_key references delivered_to envelope_to x_envelope_to meta received_recipients))
      expect(metadata[:meta]).to include(client_id: client_id, project: project.full_path)
      expect(metadata[meta_key]).to eq(meta_value)
    end
  end

  shared_examples 'failed receive' do
    it 'adds metric event' do
      expect(::Gitlab::Metrics::BackgroundTransaction).to receive(:current).and_return(metric_transaction)
      expect(metric_transaction).to receive(:add_event).with('email_receiver_error', { error: expected_error.name })

      expect { receiver.execute }.to raise_error(expected_error)
    end
  end

  context 'when the email contains a valid email address in a header' do
    before do
      stub_incoming_email_setting(enabled: true, address: "incoming+%{key}@appmail.example.com")
    end

    context 'when in a Delivered-To header' do
      let(:email_raw) { fixture_file('emails/forwarded_new_issue.eml') }
      let(:meta_key) { :delivered_to }
      let(:meta_value) { ["incoming+gitlabhq/gitlabhq+auth_token@appmail.example.com", "support@example.com"] }

      it_behaves_like 'successful receive'
    end

    context 'when in an Envelope-To header' do
      let(:email_raw) { fixture_file('emails/envelope_to_header.eml') }
      let(:meta_key) { :envelope_to }
      let(:meta_value) { ["incoming+gitlabhq/gitlabhq+auth_token@appmail.example.com"] }

      it_behaves_like 'successful receive'
    end

    context 'when in an X-Envelope-To header' do
      let(:email_raw) { fixture_file('emails/x_envelope_to_header.eml') }
      let(:meta_key) { :x_envelope_to }
      let(:meta_value) { ["incoming+gitlabhq/gitlabhq+auth_token@appmail.example.com"] }

      it_behaves_like 'successful receive'
    end

    context 'when enclosed with angle brackets in an Envelope-To header' do
      let(:email_raw) { fixture_file('emails/envelope_to_header_with_angle_brackets.eml') }
      let(:meta_key) { :envelope_to }
      let(:meta_value) { ["<incoming+gitlabhq/gitlabhq+auth_token@appmail.example.com>"] }

      it_behaves_like 'successful receive'
    end

    context 'when all other headers are missing' do
      let(:email_raw) { fixture_file('emails/missing_delivered_to_header.eml') }
      let(:meta_key) { :received_recipients }
      let(:meta_value) { ['incoming+gitlabhq/gitlabhq+auth_token@appmail.example.com', 'incoming+gitlabhq/gitlabhq@example.com'] }

      context 'when use_received_header_for_incoming_emails is enabled' do
        it_behaves_like 'successful receive'
      end

      context 'when use_received_header_for_incoming_emails is disabled' do
        let(:expected_error) { Gitlab::Email::UnknownIncomingEmail }

        before do
          stub_feature_flags(use_received_header_for_incoming_emails: false)
        end

        it_behaves_like 'failed receive'
      end
    end
  end

  context 'when we cannot find a capable handler' do
    let(:email_raw) { fixture_file('emails/valid_reply.eml').gsub(mail_key, '!!!') }
    let(:expected_error) { Gitlab::Email::UnknownIncomingEmail }

    it_behaves_like 'failed receive'
  end

  context 'when the email is blank' do
    let(:email_raw) { '' }
    let(:expected_error) { Gitlab::Email::EmptyEmailError }

    it_behaves_like 'failed receive'
  end

  context 'when the email was auto generated with Auto-Submitted header' do
    let(:email_raw) { fixture_file('emails/auto_submitted.eml') }
    let(:expected_error) { Gitlab::Email::AutoGeneratedEmailError }

    it_behaves_like 'failed receive'
  end

  context "when the email's To field is blank" do
    before do
      stub_incoming_email_setting(enabled: true, address: "incoming+%{key}@appmail.example.com")
    end

    let(:email_raw) do
      <<~EMAIL
      Delivered-To: incoming+gitlabhq/gitlabhq+auth_token@appmail.example.com
      From: "jake@example.com" <jake@example.com>
      Bcc: "support@example.com" <support@example.com>

      Email content
      EMAIL
    end

    let(:meta_key) { :delivered_to }
    let(:meta_value) { ["incoming+gitlabhq/gitlabhq+auth_token@appmail.example.com"] }

    it_behaves_like 'successful receive'
  end

  context "when the email's From field is blank" do
    before do
      stub_incoming_email_setting(enabled: true, address: "incoming+%{key}@appmail.example.com")
    end

    let(:email_raw) do
      <<~EMAIL
      Delivered-To: incoming+gitlabhq/gitlabhq+auth_token@appmail.example.com
      To: "support@example.com" <support@example.com>

      Email content
      EMAIL
    end

    let(:meta_key) { :delivered_to }
    let(:meta_value) { ["incoming+gitlabhq/gitlabhq+auth_token@appmail.example.com"] }

    it_behaves_like 'successful receive' do
      let(:client_id) { 'email/' }
    end
  end

  context 'when the email was auto generated with X-Autoreply header' do
    let(:email_raw) { fixture_file('emails/auto_reply.eml') }
    let(:expected_error) { Gitlab::Email::AutoGeneratedEmailError }

    it_behaves_like 'failed receive'
  end

  it 'requires all handlers to have a unique metric_event' do
    events = Gitlab::Email::Handler.handlers.map do |handler|
      handler.new(Mail::Message.new, 'gitlabhq/gitlabhq+auth_token').metrics_event
    end

    expect(events.uniq.count).to eq events.count
  end

  it 'requires all handlers to respond to #project' do
    Gitlab::Email::Handler.load_handlers.each do |handler|
      expect { handler.new(nil, nil).project }.not_to raise_error
    end
  end
end
