import { shallowMount } from '@vue/test-utils';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import {
  FILTERED_SEARCH_TERM,
  OPERATORS_IS,
  TOKEN_TITLE_PROJECT,
  TOKEN_TYPE_PROJECT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import ProjectToken from 'ee/usage_quotas/code_suggestions/tokens/project_token.vue';

describe('SearchAndSortBar', () => {
  let wrapper;

  const fullPath = 'namespace/full-path';
  const defaultProps = {
    namespace: fullPath,
    searchInputPlaceholder: 'Filter users',
  };

  const createComponent = ({ enableAddOnUsersFiltering = false } = {}) => {
    wrapper = shallowMount(SearchAndSortBar, {
      provide: {
        fullPath,
        glFeatures: {
          enableAddOnUsersFiltering,
        },
      },
    });
  };

  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);

  describe('renders filtered search and sort bar', () => {
    it('renders search and sort bar with default params', () => {
      createComponent();

      expect(findFilteredSearchBar().props()).toMatchObject(defaultProps);
    });

    describe('with `enableAddOnUsersFiltering`', () => {
      describe('when enabled', () => {
        it('passes the correct tokens', () => {
          createComponent({ enableAddOnUsersFiltering: true });

          expect(findFilteredSearchBar().props('tokens')).toEqual(
            expect.arrayContaining([
              expect.objectContaining({
                type: TOKEN_TYPE_PROJECT,
                icon: 'project',
                title: TOKEN_TITLE_PROJECT,
                unique: true,
                token: ProjectToken,
                operators: OPERATORS_IS,
                fullPath,
              }),
            ]),
          );
        });
      });

      describe('when disabled', () => {
        it('passes the correct tokens', () => {
          createComponent();

          expect(findFilteredSearchBar().props('tokens')).toHaveLength(0);
        });
      });
    });
  });

  describe('when searching', () => {
    describe('with search term only', () => {
      it('emits search event with appropriate params', () => {
        const searchTerm = 'search term';
        const searchTokens = [
          { type: FILTERED_SEARCH_TERM, value: { data: searchTerm } },
          { type: FILTERED_SEARCH_TERM, value: { data: '' } },
        ];

        createComponent();
        findFilteredSearchBar().vm.$emit('onFilter', searchTokens);

        expect(wrapper.emitted('onFilter')[0][0]).toStrictEqual({ search: searchTerm });
      });
    });

    describe('with search and filter terms', () => {
      it('emits search event with appropriate params', () => {
        const projectId = 'project-id';
        const searchTerm = 'search term';
        const searchTokens = [
          { type: FILTERED_SEARCH_TERM, value: { data: searchTerm } },
          { type: TOKEN_TYPE_PROJECT, value: { data: projectId } },
        ];

        createComponent();
        findFilteredSearchBar().vm.$emit('onFilter', searchTokens);

        expect(wrapper.emitted('onFilter')[0][0]).toStrictEqual({
          search: searchTerm,
          filterByProjectId: projectId,
        });
      });
    });

    describe.each([
      [[{ type: FILTERED_SEARCH_TERM, value: { data: undefined } }]],
      [[{ type: TOKEN_TYPE_PROJECT, value: { data: undefined } }]],
      [[{ type: 'status', value: { data: 'test' } }]],
    ])('with invalid type or data', (searchTokens) => {
      it('emits an empty object', () => {
        createComponent();
        findFilteredSearchBar().vm.$emit('onFilter', searchTokens);

        expect(wrapper.emitted('onFilter')[0][0]).toStrictEqual({});
      });
    });

    it.each([
      undefined,
      {},
      { type: undefined, value: undefined },
      { type: FILTERED_SEARCH_TERM, value: { data: undefined } },
    ])('emits search event with params: %s', (token) => {
      const projectId = 'project-id';
      const searchTerm = 'search term';
      const searchTokens = [
        { type: FILTERED_SEARCH_TERM, value: { data: searchTerm } },
        { type: TOKEN_TYPE_PROJECT, value: { data: projectId } },
        token,
      ];

      createComponent();
      findFilteredSearchBar().vm.$emit('onFilter', searchTokens);

      expect(wrapper.emitted('onFilter')[0][0]).toStrictEqual({
        search: searchTerm,
        filterByProjectId: projectId,
      });
    });
  });
});
