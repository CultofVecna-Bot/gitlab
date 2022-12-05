import { GlButton } from '@gitlab/ui';
import * as Sentry from '@sentry/browser';
import { mount, shallowMount } from '@vue/test-utils';
import AxiosMockAdapter from 'axios-mock-adapter';
import { cloneDeep } from 'lodash';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import getIssuesQuery from 'ee_else_ce/issues/list/queries/get_issues.query.graphql';
import getIssuesCountsQuery from 'ee_else_ce/issues/list/queries/get_issues_counts.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';
import waitForPromises from 'helpers/wait_for_promises';
import {
  getIssuesCountsQueryResponse,
  getIssuesQueryResponse,
  filteredTokens,
  locationSearch,
  setSortPreferenceMutationResponse,
  setSortPreferenceMutationResponseWithErrors,
  urlParams,
} from 'jest/issues/list/mock_data';
import { createAlert, VARIANT_INFO } from '~/flash';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import CsvImportExportButtons from '~/issuable/components/csv_import_export_buttons.vue';
import IssuableByEmail from '~/issuable/components/issuable_by_email.vue';
import IssuableList from '~/vue_shared/issuable/list/components/issuable_list_root.vue';
import { IssuableListTabs, IssuableStates } from '~/vue_shared/issuable/list/constants';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import EmptyStateWithoutAnyIssues from '~/issues/list/components/empty_state_without_any_issues.vue';
import IssuesListApp from '~/issues/list/components/issues_list_app.vue';
import NewIssueDropdown from '~/issues/list/components/new_issue_dropdown.vue';
import {
  CREATED_DESC,
  RELATIVE_POSITION,
  RELATIVE_POSITION_ASC,
  UPDATED_DESC,
  urlSortParams,
} from '~/issues/list/constants';
import eventHub from '~/issues/list/eventhub';
import setSortPreferenceMutation from '~/issues/list/queries/set_sort_preference.mutation.graphql';
import { getSortKey, getSortOptions } from '~/issues/list/utils';
import axios from '~/lib/utils/axios_utils';
import { scrollUp } from '~/lib/utils/scroll_utils';
import { joinPaths } from '~/lib/utils/url_utility';
import {
  WORK_ITEM_TYPE_ENUM_INCIDENT,
  WORK_ITEM_TYPE_ENUM_ISSUE,
  WORK_ITEM_TYPE_ENUM_TASK,
  WORK_ITEM_TYPE_ENUM_TEST_CASE,
} from '~/work_items/constants';
import {
  FILTERED_SEARCH_TERM,
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_CONFIDENTIAL,
  TOKEN_TYPE_CONTACT,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_MY_REACTION,
  TOKEN_TYPE_ORGANIZATION,
  TOKEN_TYPE_RELEASE,
  TOKEN_TYPE_TYPE,
} from '~/vue_shared/components/filtered_search_bar/constants';

import('~/issuable');
import('~/users_select');

jest.mock('@sentry/browser');
jest.mock('~/flash');
jest.mock('~/lib/utils/scroll_utils', () => ({ scrollUp: jest.fn() }));

describe('CE IssuesListApp component', () => {
  let axiosMock;
  let wrapper;

  Vue.use(VueApollo);
  Vue.use(VueRouter);

  const defaultProvide = {
    autocompleteAwardEmojisPath: 'autocomplete/award/emojis/path',
    calendarPath: 'calendar/path',
    canBulkUpdate: false,
    canCreateProjects: false,
    canReadCrmContact: false,
    canReadCrmOrganization: false,
    emptyStateSvgPath: 'empty-state.svg',
    exportCsvPath: 'export/csv/path',
    fullPath: 'path/to/project',
    hasAnyIssues: true,
    hasAnyProjects: true,
    hasBlockedIssuesFeature: true,
    hasIssuableHealthStatusFeature: true,
    hasIssueWeightsFeature: true,
    hasIterationsFeature: true,
    hasScopedLabelsFeature: true,
    initialEmail: 'email@example.com',
    initialSort: CREATED_DESC,
    isAnonymousSearchDisabled: false,
    isIssueRepositioningDisabled: false,
    isProject: true,
    isPublicVisibilityRestricted: false,
    isSignedIn: true,
    jiraIntegrationPath: 'jira/integration/path',
    newIssuePath: 'new/issue/path',
    newProjectPath: 'new/project/path',
    releasesPath: 'releases/path',
    rssPath: 'rss/path',
    showNewIssueLink: true,
    signInPath: 'sign/in/path',
  };

  let defaultQueryResponse = getIssuesQueryResponse;
  let router;
  if (IS_EE) {
    defaultQueryResponse = cloneDeep(getIssuesQueryResponse);
    defaultQueryResponse.data.project.issues.nodes[0].blockingCount = 1;
    defaultQueryResponse.data.project.issues.nodes[0].healthStatus = null;
    defaultQueryResponse.data.project.issues.nodes[0].weight = 5;
  }

  const mockIssuesQueryResponse = jest.fn().mockResolvedValue(defaultQueryResponse);
  const mockIssuesCountsQueryResponse = jest.fn().mockResolvedValue(getIssuesCountsQueryResponse);

  const findCsvImportExportButtons = () => wrapper.findComponent(CsvImportExportButtons);
  const findIssuableByEmail = () => wrapper.findComponent(IssuableByEmail);
  const findGlButtons = () => wrapper.findAllComponents(GlButton);
  const findGlButtonAt = (index) => findGlButtons().at(index);
  const findIssuableList = () => wrapper.findComponent(IssuableList);
  const findNewIssueDropdown = () => wrapper.findComponent(NewIssueDropdown);

  const mountComponent = ({
    provide = {},
    data = {},
    issuesQueryResponse = mockIssuesQueryResponse,
    issuesCountsQueryResponse = mockIssuesCountsQueryResponse,
    sortPreferenceMutationResponse = jest.fn().mockResolvedValue(setSortPreferenceMutationResponse),
    stubs = {},
    mountFn = shallowMount,
  } = {}) => {
    const requestHandlers = [
      [getIssuesQuery, issuesQueryResponse],
      [getIssuesCountsQuery, issuesCountsQueryResponse],
      [setSortPreferenceMutation, sortPreferenceMutationResponse],
    ];

    router = new VueRouter({ mode: 'history' });

    return mountFn(IssuesListApp, {
      apolloProvider: createMockApollo(requestHandlers),
      router,
      provide: {
        ...defaultProvide,
        ...provide,
      },
      data() {
        return data;
      },
      stubs,
    });
  };

  beforeEach(() => {
    setWindowLocation(TEST_HOST);
    axiosMock = new AxiosMockAdapter(axios);
  });

  afterEach(() => {
    axiosMock.reset();
    wrapper.destroy();
  });

  describe('IssuableList', () => {
    beforeEach(() => {
      wrapper = mountComponent();
      jest.runOnlyPendingTimers();
      return waitForPromises();
    });

    it('renders', () => {
      expect(findIssuableList().props()).toMatchObject({
        namespace: defaultProvide.fullPath,
        recentSearchesStorageKey: 'issues',
        searchInputPlaceholder: IssuesListApp.i18n.searchPlaceholder,
        sortOptions: getSortOptions({
          hasBlockedIssuesFeature: defaultProvide.hasBlockedIssuesFeature,
          hasIssuableHealthStatusFeature: defaultProvide.hasIssuableHealthStatusFeature,
          hasIssueWeightsFeature: defaultProvide.hasIssueWeightsFeature,
        }),
        initialSortBy: CREATED_DESC,
        issuables: getIssuesQueryResponse.data.project.issues.nodes,
        tabs: IssuableListTabs,
        currentTab: IssuableStates.Opened,
        tabCounts: {
          opened: 1,
          closed: 1,
          all: 1,
        },
        issuablesLoading: false,
        isManualOrdering: false,
        showBulkEditSidebar: false,
        showPaginationControls: true,
        useKeysetPagination: true,
        hasPreviousPage: getIssuesQueryResponse.data.project.issues.pageInfo.hasPreviousPage,
        hasNextPage: getIssuesQueryResponse.data.project.issues.pageInfo.hasNextPage,
      });
    });
  });

  describe('header action buttons', () => {
    it('renders rss button', async () => {
      wrapper = mountComponent({ mountFn: mount });
      await waitForPromises();

      expect(findGlButtonAt(0).props('icon')).toBe('rss');
      expect(findGlButtonAt(0).attributes()).toMatchObject({
        href: defaultProvide.rssPath,
        'aria-label': IssuesListApp.i18n.rssLabel,
      });
    });

    it('renders calendar button', async () => {
      wrapper = mountComponent({ mountFn: mount });
      await waitForPromises();

      expect(findGlButtonAt(1).props('icon')).toBe('calendar');
      expect(findGlButtonAt(1).attributes()).toMatchObject({
        href: defaultProvide.calendarPath,
        'aria-label': IssuesListApp.i18n.calendarLabel,
      });
    });

    describe('csv import/export component', () => {
      describe('when user is signed in', () => {
        beforeEach(() => {
          setWindowLocation('?search=refactor&state=opened');

          wrapper = mountComponent({
            provide: { initialSortBy: CREATED_DESC, isSignedIn: true },
            mountFn: mount,
          });

          jest.runOnlyPendingTimers();
          return waitForPromises();
        });

        it('renders', () => {
          expect(findCsvImportExportButtons().props()).toMatchObject({
            exportCsvPath: `${defaultProvide.exportCsvPath}?search=refactor&state=opened`,
            issuableCount: 1,
          });
        });
      });

      describe('when user is not signed in', () => {
        it('does not render', () => {
          wrapper = mountComponent({ provide: { isSignedIn: false }, mountFn: mount });

          expect(findCsvImportExportButtons().exists()).toBe(false);
        });
      });

      describe('when in a group context', () => {
        it('does not render', () => {
          wrapper = mountComponent({ provide: { isProject: false }, mountFn: mount });

          expect(findCsvImportExportButtons().exists()).toBe(false);
        });
      });
    });

    describe('bulk edit button', () => {
      it('renders when user has permissions', () => {
        wrapper = mountComponent({ provide: { canBulkUpdate: true }, mountFn: mount });

        expect(findGlButtonAt(2).text()).toBe('Edit issues');
      });

      it('does not render when user does not have permissions', () => {
        wrapper = mountComponent({ provide: { canBulkUpdate: false }, mountFn: mount });

        expect(findGlButtons().filter((button) => button.text() === 'Edit issues')).toHaveLength(0);
      });

      it('emits "issuables:enableBulkEdit" event to legacy bulk edit class', async () => {
        wrapper = mountComponent({ provide: { canBulkUpdate: true }, mountFn: mount });
        jest.spyOn(eventHub, '$emit');

        findGlButtonAt(2).vm.$emit('click');
        await waitForPromises();

        expect(eventHub.$emit).toHaveBeenCalledWith('issuables:enableBulkEdit');
      });
    });

    describe('new issue button', () => {
      it('renders when user has permissions', () => {
        wrapper = mountComponent({ provide: { showNewIssueLink: true }, mountFn: mount });

        expect(findGlButtonAt(2).text()).toBe('New issue');
        expect(findGlButtonAt(2).attributes('href')).toBe(defaultProvide.newIssuePath);
      });

      it('does not render when user does not have permissions', () => {
        wrapper = mountComponent({ provide: { showNewIssueLink: false }, mountFn: mount });

        expect(findGlButtons().filter((button) => button.text() === 'New issue')).toHaveLength(0);
      });
    });

    describe('new issue split dropdown', () => {
      it('does not render in a project context', () => {
        wrapper = mountComponent({ provide: { isProject: true }, mountFn: mount });

        expect(findNewIssueDropdown().exists()).toBe(false);
      });

      it('renders in a group context', () => {
        wrapper = mountComponent({ provide: { isProject: false }, mountFn: mount });

        expect(findNewIssueDropdown().exists()).toBe(true);
      });
    });
  });

  describe('initial url params', () => {
    describe('page', () => {
      it('page_after is set from the url params', () => {
        setWindowLocation('?page_after=randomCursorString&first_page_size=20');
        wrapper = mountComponent();

        expect(wrapper.vm.$route.query).toMatchObject({
          page_after: 'randomCursorString',
          first_page_size: '20',
        });
      });

      it('page_before is set from the url params', () => {
        setWindowLocation('?page_before=anotherRandomCursorString&last_page_size=20');
        wrapper = mountComponent();

        expect(wrapper.vm.$route.query).toMatchObject({
          page_before: 'anotherRandomCursorString',
          last_page_size: '20',
        });
      });
    });

    describe('search', () => {
      it('is set from the url params', () => {
        setWindowLocation(locationSearch);
        wrapper = mountComponent();

        expect(wrapper.vm.$route.query).toMatchObject({ search: 'find issues' });
      });
    });

    describe('sort', () => {
      describe('when initial sort value uses old enum values', () => {
        const oldEnumSortValues = Object.values(urlSortParams);

        it.each(oldEnumSortValues)('initial sort is set with value %s', (sort) => {
          wrapper = mountComponent({ provide: { initialSort: sort } });

          expect(findIssuableList().props('initialSortBy')).toBe(getSortKey(sort));
        });
      });

      describe('when initial sort value uses new GraphQL enum values', () => {
        const graphQLEnumSortValues = Object.keys(urlSortParams);

        it.each(graphQLEnumSortValues)('initial sort is set with value %s', (sort) => {
          wrapper = mountComponent({ provide: { initialSort: sort.toLowerCase() } });

          expect(findIssuableList().props('initialSortBy')).toBe(sort);
        });
      });

      describe('when initial sort value is invalid', () => {
        it.each(['', 'asdf', null, undefined])(
          'initial sort is set to value CREATED_DESC',
          (sort) => {
            wrapper = mountComponent({ provide: { initialSort: sort } });

            expect(findIssuableList().props('initialSortBy')).toBe(CREATED_DESC);
          },
        );
      });

      describe('when sort is manual and issue repositioning is disabled', () => {
        beforeEach(() => {
          wrapper = mountComponent({
            provide: { initialSort: RELATIVE_POSITION, isIssueRepositioningDisabled: true },
          });
        });

        it('changes the sort to the default of created descending', () => {
          expect(findIssuableList().props('initialSortBy')).toBe(CREATED_DESC);
        });

        it('shows an alert to tell the user that manual reordering is disabled', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: IssuesListApp.i18n.issueRepositioningMessage,
            variant: VARIANT_INFO,
          });
        });
      });
    });

    describe('state', () => {
      it('is set from the url params', () => {
        const initialState = IssuableStates.All;
        setWindowLocation(`?state=${initialState}`);
        wrapper = mountComponent();

        expect(findIssuableList().props('currentTab')).toBe(initialState);
      });
    });

    describe('filter tokens', () => {
      it('is set from the url params', () => {
        setWindowLocation(locationSearch);
        wrapper = mountComponent();

        expect(findIssuableList().props('initialFilterValue')).toEqual(filteredTokens);
      });

      describe('when anonymous searching is performed', () => {
        beforeEach(() => {
          setWindowLocation(locationSearch);
          wrapper = mountComponent({
            provide: { isAnonymousSearchDisabled: true, isSignedIn: false },
          });
        });

        it('is set from url params and removes search terms', () => {
          const expected = filteredTokens.filter((token) => token.type !== FILTERED_SEARCH_TERM);
          expect(findIssuableList().props('initialFilterValue')).toEqual(expected);
        });

        it('shows an alert to tell the user they must be signed in to search', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: IssuesListApp.i18n.anonymousSearchingMessage,
            variant: VARIANT_INFO,
          });
        });
      });
    });
  });

  describe('bulk edit', () => {
    describe.each([true, false])(
      'when "issuables:toggleBulkEdit" event is received with payload `%s`',
      (isBulkEdit) => {
        beforeEach(() => {
          wrapper = mountComponent();

          eventHub.$emit('issuables:toggleBulkEdit', isBulkEdit);
        });

        it(`${isBulkEdit ? 'enables' : 'disables'} bulk edit`, () => {
          expect(findIssuableList().props('showBulkEditSidebar')).toBe(isBulkEdit);
        });
      },
    );
  });

  describe('IssuableByEmail component', () => {
    describe.each`
      initialEmail | hasAnyIssues | isSignedIn | exists
      ${false}     | ${false}     | ${false}   | ${false}
      ${false}     | ${true}      | ${false}   | ${false}
      ${false}     | ${false}     | ${true}    | ${false}
      ${false}     | ${true}      | ${true}    | ${false}
      ${true}      | ${false}     | ${false}   | ${false}
      ${true}      | ${true}      | ${false}   | ${false}
      ${true}      | ${false}     | ${true}    | ${true}
      ${true}      | ${true}      | ${true}    | ${true}
    `(
      `when issue creation by email is enabled=$initialEmail`,
      ({ initialEmail, hasAnyIssues, isSignedIn, exists }) => {
        it(`${initialEmail ? 'renders' : 'does not render'}`, () => {
          wrapper = mountComponent({ provide: { initialEmail, hasAnyIssues, isSignedIn } });

          expect(findIssuableByEmail().exists()).toBe(exists);
        });
      },
    );
  });

  describe('empty states', () => {
    describe('when there are issues', () => {
      beforeEach(() => {
        wrapper = mountComponent({ provide: { hasAnyIssues: true }, mountFn: mount });
      });

      it('shows EmptyStateWithAnyIssues empty state', () => {
        expect(wrapper.findComponent(EmptyStateWithAnyIssues).props()).toEqual({
          hasSearch: false,
          isOpenTab: true,
        });
      });
    });

    describe('when there are no issues', () => {
      beforeEach(() => {
        wrapper = mountComponent({ provide: { hasAnyIssues: false } });
      });

      it('shows EmptyStateWithoutAnyIssues empty state', () => {
        expect(wrapper.findComponent(EmptyStateWithoutAnyIssues).props()).toEqual({
          currentTabCount: 0,
          exportCsvPathWithQuery: defaultProvide.exportCsvPath,
          showCsvButtons: true,
          showNewIssueDropdown: false,
        });
      });
    });
  });

  describe('tokens', () => {
    const mockCurrentUser = {
      id: 1,
      name: 'Administrator',
      username: 'root',
      avatar_url: 'avatar/url',
    };

    describe('when user is signed out', () => {
      beforeEach(() => {
        wrapper = mountComponent({ provide: { isSignedIn: false } });
      });

      it('does not render My-Reaction or Confidential tokens', () => {
        expect(findIssuableList().props('searchTokens')).not.toMatchObject([
          { type: TOKEN_TYPE_AUTHOR, preloadedAuthors: [mockCurrentUser] },
          { type: TOKEN_TYPE_ASSIGNEE, preloadedAuthors: [mockCurrentUser] },
          { type: TOKEN_TYPE_MY_REACTION },
          { type: TOKEN_TYPE_CONFIDENTIAL },
        ]);
      });
    });

    describe('when user does not have CRM enabled', () => {
      beforeEach(() => {
        wrapper = mountComponent({
          provide: { canReadCrmContact: false, canReadCrmOrganization: false },
        });
      });

      it('does not render Contact or Organization tokens', () => {
        expect(findIssuableList().props('searchTokens')).not.toMatchObject([
          { type: TOKEN_TYPE_CONTACT },
          { type: TOKEN_TYPE_ORGANIZATION },
        ]);
      });
    });

    describe('when all tokens are available', () => {
      const originalGon = window.gon;

      beforeEach(() => {
        window.gon = {
          ...originalGon,
          current_user_id: mockCurrentUser.id,
          current_user_fullname: mockCurrentUser.name,
          current_username: mockCurrentUser.username,
          current_user_avatar_url: mockCurrentUser.avatar_url,
        };

        wrapper = mountComponent({
          provide: {
            canReadCrmContact: true,
            canReadCrmOrganization: true,
            isSignedIn: true,
          },
        });
      });

      afterEach(() => {
        window.gon = originalGon;
      });

      it('renders all tokens alphabetically', () => {
        const preloadedAuthors = [
          { ...mockCurrentUser, id: convertToGraphQLId('User', mockCurrentUser.id) },
        ];

        expect(findIssuableList().props('searchTokens')).toMatchObject([
          { type: TOKEN_TYPE_ASSIGNEE, preloadedAuthors },
          { type: TOKEN_TYPE_AUTHOR, preloadedAuthors },
          { type: TOKEN_TYPE_CONFIDENTIAL },
          { type: TOKEN_TYPE_CONTACT },
          { type: TOKEN_TYPE_LABEL },
          { type: TOKEN_TYPE_MILESTONE },
          { type: TOKEN_TYPE_MY_REACTION },
          { type: TOKEN_TYPE_ORGANIZATION },
          { type: TOKEN_TYPE_RELEASE },
          { type: TOKEN_TYPE_TYPE },
        ]);
      });
    });
  });

  describe('errors', () => {
    describe.each`
      error                      | mountOption                    | message
      ${'fetching issues'}       | ${'issuesQueryResponse'}       | ${IssuesListApp.i18n.errorFetchingIssues}
      ${'fetching issue counts'} | ${'issuesCountsQueryResponse'} | ${IssuesListApp.i18n.errorFetchingCounts}
    `('when there is an error $error', ({ mountOption, message }) => {
      beforeEach(() => {
        wrapper = mountComponent({
          [mountOption]: jest.fn().mockRejectedValue(new Error('ERROR')),
        });
        jest.runOnlyPendingTimers();
        return waitForPromises();
      });

      it('shows an error message', () => {
        expect(findIssuableList().props('error')).toBe(message);
        expect(Sentry.captureException).toHaveBeenCalledWith(new Error('ERROR'));
      });
    });

    it('clears error message when "dismiss-alert" event is emitted from IssuableList', () => {
      wrapper = mountComponent({ issuesQueryResponse: jest.fn().mockRejectedValue(new Error()) });

      findIssuableList().vm.$emit('dismiss-alert');

      expect(findIssuableList().props('error')).toBeNull();
    });
  });

  describe('events', () => {
    describe('when "click-tab" event is emitted by IssuableList', () => {
      beforeEach(() => {
        wrapper = mountComponent();
        router.push = jest.fn();

        findIssuableList().vm.$emit('click-tab', IssuableStates.Closed);
      });

      it('updates ui to the new tab', () => {
        expect(findIssuableList().props('currentTab')).toBe(IssuableStates.Closed);
      });

      it('updates url to the new tab', () => {
        expect(router.push).toHaveBeenCalledWith({
          query: expect.objectContaining({ state: IssuableStates.Closed }),
        });
      });
    });

    describe.each`
      event | params
      ${'next-page'} | ${{
  page_after: 'endCursor',
  page_before: undefined,
  first_page_size: 20,
  last_page_size: undefined,
}}
      ${'previous-page'} | ${{
  page_after: undefined,
  page_before: 'startCursor',
  first_page_size: undefined,
  last_page_size: 20,
}}
    `('when "$event" event is emitted by IssuableList', ({ event, params }) => {
      beforeEach(() => {
        wrapper = mountComponent({
          data: {
            pageInfo: {
              endCursor: 'endCursor',
              startCursor: 'startCursor',
            },
          },
        });
        router.push = jest.fn();

        findIssuableList().vm.$emit(event);
      });

      it('scrolls to the top', () => {
        expect(scrollUp).toHaveBeenCalled();
      });

      it(`updates url`, () => {
        expect(router.push).toHaveBeenCalledWith({
          query: expect.objectContaining(params),
        });
      });
    });

    describe('when "reorder" event is emitted by IssuableList', () => {
      const issueOne = {
        ...defaultQueryResponse.data.project.issues.nodes[0],
        id: 'gid://gitlab/Issue/1',
        iid: '101',
        reference: 'group/project#1',
        webPath: '/group/project/-/issues/1',
      };
      const issueTwo = {
        ...defaultQueryResponse.data.project.issues.nodes[0],
        id: 'gid://gitlab/Issue/2',
        iid: '102',
        reference: 'group/project#2',
        webPath: '/group/project/-/issues/2',
      };
      const issueThree = {
        ...defaultQueryResponse.data.project.issues.nodes[0],
        id: 'gid://gitlab/Issue/3',
        iid: '103',
        reference: 'group/project#3',
        webPath: '/group/project/-/issues/3',
      };
      const issueFour = {
        ...defaultQueryResponse.data.project.issues.nodes[0],
        id: 'gid://gitlab/Issue/4',
        iid: '104',
        reference: 'group/project#4',
        webPath: '/group/project/-/issues/4',
      };
      const response = (isProject = true) => ({
        data: {
          [isProject ? 'project' : 'group']: {
            id: '1',
            issues: {
              ...defaultQueryResponse.data.project.issues,
              nodes: [issueOne, issueTwo, issueThree, issueFour],
            },
          },
        },
      });

      describe('when successful', () => {
        describe.each([true, false])('when isProject=%s', (isProject) => {
          describe.each`
            description                       | issueToMove   | oldIndex | newIndex | moveBeforeId    | moveAfterId
            ${'to the beginning of the list'} | ${issueThree} | ${2}     | ${0}     | ${null}         | ${issueOne.id}
            ${'down the list'}                | ${issueOne}   | ${0}     | ${1}     | ${issueTwo.id}  | ${issueThree.id}
            ${'up the list'}                  | ${issueThree} | ${2}     | ${1}     | ${issueOne.id}  | ${issueTwo.id}
            ${'to the end of the list'}       | ${issueTwo}   | ${1}     | ${3}     | ${issueFour.id} | ${null}
          `(
            'when moving issue $description',
            ({ issueToMove, oldIndex, newIndex, moveBeforeId, moveAfterId }) => {
              beforeEach(() => {
                wrapper = mountComponent({
                  provide: { isProject },
                  issuesQueryResponse: jest.fn().mockResolvedValue(response(isProject)),
                });
                jest.runOnlyPendingTimers();
                return waitForPromises();
              });

              it('makes API call to reorder the issue', async () => {
                findIssuableList().vm.$emit('reorder', { oldIndex, newIndex });
                await waitForPromises();

                expect(axiosMock.history.put[0]).toMatchObject({
                  url: joinPaths(issueToMove.webPath, 'reorder'),
                  data: JSON.stringify({
                    move_before_id: getIdFromGraphQLId(moveBeforeId),
                    move_after_id: getIdFromGraphQLId(moveAfterId),
                  }),
                });
              });
            },
          );
        });
      });

      describe('when unsuccessful', () => {
        beforeEach(() => {
          wrapper = mountComponent({
            issuesQueryResponse: jest.fn().mockResolvedValue(response()),
          });
          jest.runOnlyPendingTimers();
          return waitForPromises();
        });

        it('displays an error message', async () => {
          axiosMock.onPut(joinPaths(issueOne.webPath, 'reorder')).reply(500);

          findIssuableList().vm.$emit('reorder', { oldIndex: 0, newIndex: 1 });
          await waitForPromises();

          expect(findIssuableList().props('error')).toBe(IssuesListApp.i18n.reorderError);
          expect(Sentry.captureException).toHaveBeenCalledWith(
            new Error('Request failed with status code 500'),
          );
        });
      });
    });

    describe('when "sort" event is emitted by IssuableList', () => {
      it.each(Object.keys(urlSortParams))(
        'updates to the new sort when payload is `%s`',
        async (sortKey) => {
          // Ensure initial sort key is different so we can trigger an update when emitting a sort key
          wrapper =
            sortKey === CREATED_DESC
              ? mountComponent({ provide: { initialSort: UPDATED_DESC } })
              : mountComponent();
          router.push = jest.fn();

          findIssuableList().vm.$emit('sort', sortKey);
          jest.runOnlyPendingTimers();
          await nextTick();

          expect(router.push).toHaveBeenCalledWith({
            query: expect.objectContaining({ sort: urlSortParams[sortKey] }),
          });
        },
      );

      describe('when issue repositioning is disabled', () => {
        const initialSort = CREATED_DESC;

        beforeEach(() => {
          wrapper = mountComponent({
            provide: { initialSort, isIssueRepositioningDisabled: true },
          });
          router.push = jest.fn();

          findIssuableList().vm.$emit('sort', RELATIVE_POSITION_ASC);
        });

        it('does not update the sort to manual', () => {
          expect(router.push).not.toHaveBeenCalled();
        });

        it('shows an alert to tell the user that manual reordering is disabled', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: IssuesListApp.i18n.issueRepositioningMessage,
            variant: VARIANT_INFO,
          });
        });
      });

      describe('when user is signed in', () => {
        it('calls mutation to save sort preference', () => {
          const mutationMock = jest.fn().mockResolvedValue(setSortPreferenceMutationResponse);
          wrapper = mountComponent({ sortPreferenceMutationResponse: mutationMock });

          findIssuableList().vm.$emit('sort', UPDATED_DESC);

          expect(mutationMock).toHaveBeenCalledWith({ input: { issuesSort: UPDATED_DESC } });
        });

        it('captures error when mutation response has errors', async () => {
          const mutationMock = jest
            .fn()
            .mockResolvedValue(setSortPreferenceMutationResponseWithErrors);
          wrapper = mountComponent({ sortPreferenceMutationResponse: mutationMock });

          findIssuableList().vm.$emit('sort', UPDATED_DESC);
          await waitForPromises();

          expect(Sentry.captureException).toHaveBeenCalledWith(new Error('oh no!'));
        });
      });

      describe('when user is signed out', () => {
        it('does not call mutation to save sort preference', () => {
          const mutationMock = jest.fn().mockResolvedValue(setSortPreferenceMutationResponse);
          wrapper = mountComponent({
            provide: { isSignedIn: false },
            sortPreferenceMutationResponse: mutationMock,
          });

          findIssuableList().vm.$emit('sort', CREATED_DESC);

          expect(mutationMock).not.toHaveBeenCalled();
        });
      });
    });

    describe('when "update-legacy-bulk-edit" event is emitted by IssuableList', () => {
      beforeEach(() => {
        wrapper = mountComponent();
        jest.spyOn(eventHub, '$emit');

        findIssuableList().vm.$emit('update-legacy-bulk-edit');
      });

      it('emits an "issuables:updateBulkEdit" event to the legacy bulk edit class', () => {
        expect(eventHub.$emit).toHaveBeenCalledWith('issuables:updateBulkEdit');
      });
    });

    describe('when "filter" event is emitted by IssuableList', () => {
      it('updates IssuableList with url params', async () => {
        wrapper = mountComponent();
        router.push = jest.fn();

        findIssuableList().vm.$emit('filter', filteredTokens);
        await nextTick();

        expect(router.push).toHaveBeenCalledWith({
          query: expect.objectContaining(urlParams),
        });
      });

      describe('when anonymous searching is performed', () => {
        beforeEach(() => {
          wrapper = mountComponent({
            provide: { isAnonymousSearchDisabled: true, isSignedIn: false },
          });
          router.push = jest.fn();

          findIssuableList().vm.$emit('filter', filteredTokens);
        });

        it('removes search terms', () => {
          const expected = filteredTokens.filter((token) => token.type !== FILTERED_SEARCH_TERM);
          expect(findIssuableList().props('initialFilterValue')).toEqual(expected);
        });

        it('shows an alert to tell the user they must be signed in to search', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: IssuesListApp.i18n.anonymousSearchingMessage,
            variant: VARIANT_INFO,
          });
        });
      });
    });

    describe('when "page-size-change" event is emitted by IssuableList', () => {
      it('updates url params with new page size', async () => {
        wrapper = mountComponent();
        router.push = jest.fn();

        findIssuableList().vm.$emit('page-size-change', 50);
        await nextTick();

        expect(router.push).toHaveBeenCalledTimes(1);
        expect(router.push).toHaveBeenCalledWith({
          query: expect.objectContaining({ first_page_size: 50 }),
        });
      });
    });
  });

  describe('public visibility', () => {
    it.each`
      description                                                                    | isPublicVisibilityRestricted | isSignedIn | hideUsers
      ${'shows users when public visibility is not restricted and is not signed in'} | ${false}                     | ${false}   | ${false}
      ${'shows users when public visibility is not restricted and is signed in'}     | ${false}                     | ${true}    | ${false}
      ${'hides users when public visibility is restricted and is not signed in'}     | ${true}                      | ${false}   | ${true}
      ${'shows users when public visibility is restricted and is signed in'}         | ${true}                      | ${true}    | ${false}
    `('$description', ({ isPublicVisibilityRestricted, isSignedIn, hideUsers }) => {
      const mockQuery = jest.fn().mockResolvedValue(defaultQueryResponse);
      wrapper = mountComponent({
        provide: { isPublicVisibilityRestricted, isSignedIn },
        issuesQueryResponse: mockQuery,
      });
      jest.runOnlyPendingTimers();

      expect(mockQuery).toHaveBeenCalledWith(expect.objectContaining({ hideUsers }));
    });
  });

  describe('fetching issues', () => {
    beforeEach(() => {
      wrapper = mountComponent();
      jest.runOnlyPendingTimers();
    });

    it('fetches issue, incident, test case, and task types', () => {
      const types = [
        WORK_ITEM_TYPE_ENUM_ISSUE,
        WORK_ITEM_TYPE_ENUM_INCIDENT,
        WORK_ITEM_TYPE_ENUM_TEST_CASE,
        WORK_ITEM_TYPE_ENUM_TASK,
      ];

      expect(mockIssuesQueryResponse).toHaveBeenCalledWith(expect.objectContaining({ types }));
      expect(mockIssuesCountsQueryResponse).toHaveBeenCalledWith(
        expect.objectContaining({ types }),
      );
    });
  });
});
