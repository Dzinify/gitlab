# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Email::Receiver do
  include_context :email_shared_context

  shared_examples 'correctly finds the mail key' do
    specify do
      expect(Gitlab::Email::Handler).to receive(:for).with(an_instance_of(Mail::Message), 'gitlabhq/gitlabhq+auth_token').and_return(handler)

      receiver.execute
    end
  end

  context 'when the email contains a valid email address in a header' do
    let(:handler) { double(:handler) }

    before do
      allow(handler).to receive(:execute)
      allow(handler).to receive(:metrics_params)
      allow(handler).to receive(:metrics_event)

      stub_incoming_email_setting(enabled: true, address: "incoming+%{key}@appmail.example.com")
    end

    context 'when in a Delivered-To header' do
      let(:email_raw) { fixture_file('emails/forwarded_new_issue.eml') }

      it_behaves_like 'correctly finds the mail key'
    end

    context 'when in an Envelope-To header' do
      let(:email_raw) { fixture_file('emails/envelope_to_header.eml') }

      it_behaves_like 'correctly finds the mail key'
    end

    context 'when enclosed with angle brackets in an Envelope-To header' do
      let(:email_raw) { fixture_file('emails/envelope_to_header_with_angle_brackets.eml') }

      it_behaves_like 'correctly finds the mail key'
    end
  end

  context "when we cannot find a capable handler" do
    let(:email_raw) { fixture_file('emails/valid_reply.eml').gsub(mail_key, "!!!") }

    it "raises an UnknownIncomingEmail error" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::UnknownIncomingEmail)
    end
  end

  context "when the email is blank" do
    let(:email_raw) { "" }

    it "raises an EmptyEmailError" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::EmptyEmailError)
    end
  end

  context "when the email was auto generated with Auto-Submitted header" do
    let(:email_raw) { fixture_file("emails/auto_submitted.eml") }

    it "raises an AutoGeneratedEmailError" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::AutoGeneratedEmailError)
    end
  end

  context "when the email was auto generated with X-Autoreply header" do
    let(:email_raw) { fixture_file("emails/auto_reply.eml") }

    it "raises an AutoGeneratedEmailError" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::AutoGeneratedEmailError)
    end
  end

  it "requires all handlers to have a unique metric_event" do
    events = Gitlab::Email::Handler.handlers.map do |handler|
      handler.new(Mail::Message.new, 'gitlabhq/gitlabhq+auth_token').metrics_event
    end

    expect(events.uniq.count).to eq events.count
  end
end
