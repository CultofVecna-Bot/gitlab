# frozen_string_literal: true

require 'spec_helper'

describe WikiPages::EventCreateService do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  subject { described_class.new(user) }

  describe '#execute' do
    let_it_be(:page) { create(:wiki_page, project: project) }
    let(:slug) { generate(:sluggified_title) }
    let(:action) { Event::CREATED }
    let(:response) { subject.execute(slug, page, action) }

    context 'feature flag is not enabled' do
      before do
        stub_feature_flags(wiki_events: false)
      end

      it 'does not error' do
        expect(response).to be_success
          .and have_attributes(message: /No event created/)
      end

      it 'does not create an event' do
        expect { response }.not_to change(Event, :count)
      end
    end

    context 'the action is illegal' do
      let(:action) { Event::WIKI_ACTIONS.max + 1 }

      it 'returns an error' do
        expect(response).to be_error
      end
    end

    it 'returns a successful response' do
      expect(response).to be_success
    end

    context 'the action is a deletion' do
      let(:action) { Event::DESTROYED }

      it 'does not synchronize the wiki metadata timestamps with the git commit' do
        expect_next_instance_of(WikiPage::Meta) do |instance|
          expect(instance).not_to receive(:synch_times_with_page)
        end

        response
      end
    end

    it 'creates a wiki page event' do
      expect { response }.to change(Event, :count).by(1)
    end

    it 'returns an event in the payload' do
      expect(response.payload).to include(event: have_attributes(author: user, wiki_page?: true, action: action))
    end

    it 'records the slug for the page' do
      response
      meta = WikiPage::Meta.find_or_create(page.slug, page)

      expect(meta.slugs.pluck(:slug)).to include(slug)
    end
  end
end
