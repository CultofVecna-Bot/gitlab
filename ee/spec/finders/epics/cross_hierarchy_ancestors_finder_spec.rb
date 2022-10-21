# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::CrossHierarchyAncestorsFinder do
  let_it_be(:user) { create(:user) }
  let_it_be(:search_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:another_group) { create(:group) }
  let_it_be(:reference_time) { Time.parse('2020-09-15 01:00') } # Arbitrary time used for time/date range filters
  let_it_be(:label) { create(:group_label, group: group) }

  let_it_be(:epic1) do
    create(:epic, :opened, group: another_group, title: 'This is awesome epic',
                           created_at: 1.week.before(reference_time),
                           end_date: 10.days.before(reference_time), labels: [label],
                           iid: 9835)
  end

  let_it_be(:epic2, reload: true) do
    create(:epic, :opened, parent: epic1, group: group, created_at: 4.days.before(reference_time),
                           author: user, start_date: 2.days.before(reference_time),
                           end_date: 3.days.since(reference_time), iid: 9834)
  end

  let_it_be(:epic3, reload: true) do
    create(:epic, :closed, parent: epic2, group: another_group, description: 'not so awesome',
                           start_date: 5.days.before(reference_time),
                           end_date: 3.days.before(reference_time), iid: 6873)
  end

  let_it_be(:epic4) do
    create(:epic, parent: epic3, group: group, start_date: 6.days.before(reference_time),
                  end_date: 6.days.before(reference_time), iid: 8876)
  end

  it_behaves_like 'epic findable finder'

  describe '#execute' do
    def epics(params = {})
      params[:child] ||= epic4

      described_class.new(search_user, params).execute
    end

    context 'when epics feature is disabled' do
      before do
        group.add_developer(search_user)
      end

      it 'raises an exception' do
        expect { described_class.new(search_user).execute }.to raise_error { ArgumentError }
      end
    end

    # Enabling the `request_store` for this to avoid counting queries that check
    # the license.
    context 'when epics feature is enabled', :request_store do
      before do
        stub_licensed_features(epics: true)
      end

      context 'without param' do
        it 'raises an error when child param is missing' do
          expect { described_class.new(search_user).execute }.to raise_error { ArgumentError }
        end
      end

      context 'when user can not read the epic' do
        it 'returns empty collection' do
          expect(epics).to be_empty
        end
      end

      context 'with correct params' do
        before do
          group.add_developer(search_user) if search_user
        end

        it 'returns all ancestor epics even if user can not access them' do
          expect(epics).to eq([epic3, epic2, epic1])
        end

        context 'with created_at' do
          it 'returns all epics created before the given date' do
            expect(epics(created_before: 2.days.before(reference_time))).to eq([epic2, epic1])
          end

          it 'returns all epics created after the given date' do
            expect(epics(created_after: 2.days.before(reference_time))).to contain_exactly(epic3)
          end

          it 'returns all epics created within the given interval' do
            expect(epics(created_after: 5.days.before(reference_time), created_before: 1.day.before(reference_time)))
              .to contain_exactly(epic2)
          end
        end

        context 'with search' do
          it 'returns all epics that match the search' do
            expect(epics(search: 'awesome')).to eq([epic3, epic1])
          end

          context 'with anonymous user' do
            let_it_be(:public_group) { create(:group, :public) }
            let_it_be(:epic5) { create(:epic, group: public_group, title: 'tanuki') }
            let_it_be(:epic6) { create(:epic, parent: epic5, group: public_group, title: 'ikunat') }
            let_it_be(:epic7) { create(:epic, parent: epic6, group: public_group) }

            let(:search_user) { nil }
            let(:params) { { child: epic7, search: 'tanuki' } }

            context 'with disable_anonymous_search feature flag enabled' do
              before do
                stub_feature_flags(disable_anonymous_search: true)
              end

              it 'does not perform search' do
                expect(epics(params)).to eq([epic6, epic5])
              end
            end

            context 'with disable_anonymous_search feature flag disabled' do
              before do
                stub_feature_flags(disable_anonymous_search: false)
              end

              it 'returns matching epics' do
                expect(epics(params)).to contain_exactly(epic5)
              end
            end
          end
        end

        context 'with user reaction emoji' do
          it 'returns epics reacted to by user' do
            create(:award_emoji, name: 'thumbsup', awardable: epic1, user: search_user )
            create(:award_emoji, name: 'star', awardable: epic3, user: search_user )

            expect(epics(my_reaction_emoji: 'star')).to contain_exactly(epic3)
          end
        end

        context 'with author' do
          it 'returns all epics authored by the given user' do
            expect(epics(author_id: user.id)).to contain_exactly(epic2)
          end

          context 'when using OR' do
            it 'returns all epics authored by any of the given users' do
              expect(epics(or: { author_username: [epic2.author.username, epic3.author.username] }))
                .to eq([epic3, epic2])
            end

            context 'when feature flag is disabled' do
              before do
                stub_feature_flags(or_issuable_queries: false)
              end

              it 'does not add any filter' do
                expect(epics(or: { author_username: [epic2.author.username, epic3.author.username] }))
                  .to eq([epic3, epic2, epic1])
              end
            end
          end
        end

        context 'with label' do
          it 'returns all epics with given label' do
            expect(epics(child: epic4, label_name: label.title)).to contain_exactly(epic1)
          end

          it 'returns all epics without negated label' do
            expect(epics(child: epic4, not: { label_name: [label.title] })).to eq([epic3, epic2])
          end
        end

        context 'with state' do
          it 'returns all epics with given state' do
            expect(epics(state: :closed)).to contain_exactly(epic3)
          end
        end

        context 'with timeframe' do
          it 'returns epics which start in the timeframe' do
            params = {
              start_date: 2.days.before(reference_time).strftime('%Y-%m-%d'),
              end_date: 1.day.before(reference_time).strftime('%Y-%m-%d')
            }

            expect(epics(params)).to contain_exactly(epic2)
          end

          it 'returns epics which end in the timeframe' do
            params = {
              start_date: 4.days.before(reference_time).strftime('%Y-%m-%d'),
              end_date: 3.days.before(reference_time).strftime('%Y-%m-%d')
            }

            expect(epics(params)).to contain_exactly(epic3)
          end

          it 'returns epics which start before and end after the timeframe' do
            params = {
              start_date: 4.days.before(reference_time).strftime('%Y-%m-%d'),
              end_date: 4.days.before(reference_time).strftime('%Y-%m-%d')
            }

            expect(epics(params)).to contain_exactly(epic3)
          end

          describe 'when one of the timeframe params are missing' do
            it 'does not filter by timeframe if start_date is missing' do
              only_end_date = epics(end_date: 1.year.before(reference_time).strftime('%Y-%m-%d'))

              expect(only_end_date).to eq(epics)
            end

            it 'does not filter by timeframe if end_date is missing' do
              only_start_date = epics(start_date: 1.year.since(reference_time).strftime('%Y-%m-%d'))

              expect(only_start_date).to eq(epics)
            end
          end
        end

        context 'with parent' do
          it 'returns direct children of the parent' do
            params = { child: epic4, parent_id: epic1.id }

            expect(epics(params)).to contain_exactly(epic2)
          end
        end

        context 'with milestone' do
          let_it_be(:project) { create(:project, group: group) }
          let_it_be(:another_project) { create(:project, group: another_group) }
          let_it_be(:group_milestone) { create(:milestone, group: group, title: 'test') }
          let_it_be(:another_milestone) { create(:milestone, project: another_project, title: 'test') }
          let_it_be(:issue) { create(:issue, project: project, milestone: group_milestone) }
          let_it_be(:another_issue) { create(:issue, project: another_project, milestone: another_milestone) }
          let_it_be(:epic_issue) { create(:epic_issue, epic: epic2, issue: issue) }
          let_it_be(:another_epic_issue) { create(:epic_issue, epic: epic3, issue: another_issue) }

          it 'returns empty result if the milestone is not present' do
            params = { milestone_title: 'milestone title' }

            expect(epics(params)).to be_empty
          end

          it 'returns only ancestors which have an issue from the milestone' do
            params = { milestone_title: 'test' }

            expect(epics(params)).to eq([epic3, epic2])
          end
        end

        context 'when using iid starts with query' do
          it 'returns the expected epics if just the first two numbers are given' do
            params = { iid_starts_with: '98' }

            expect(epics(params)).to eq([epic2, epic1])
          end

          it 'returns the expected epics if the exact id is given' do
            params = { iid_starts_with: '9835' }

            expect(epics(params)).to contain_exactly(epic1)
          end

          it 'fails if iid_starts_with contains a non-numeric string' do
            expect { epics({ iid_starts_with: 'foo' }) }.to raise_error(ArgumentError)
          end

          it 'fails if iid_starts_with contains a non-numeric string with line breaks' do
            expect { epics({ iid_starts_with: "foo\n1" }) }.to raise_error(ArgumentError)
          end

          it 'fails if iid_starts_with contains a string which contains a negative number' do
            expect { epics(iid_starts_with: '-1') }.to raise_error(ArgumentError)
          end
        end
      end
    end
  end
end
