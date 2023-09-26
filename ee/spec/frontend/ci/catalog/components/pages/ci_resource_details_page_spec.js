import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { GlEmptyState } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { CI_CATALOG_RESOURCE_TYPE, cacheConfig } from 'ee/ci/catalog/graphql/settings';

import getCiCatalogResourceSharedData from 'ee/ci/catalog/graphql/queries/get_ci_catalog_resource_shared_data.query.graphql';
import getCiCatalogResourceDetails from 'ee/ci/catalog/graphql/queries/get_ci_catalog_resource_details.query.graphql';

import CiResourceDetails from 'ee/ci/catalog/components/details/ci_resource_details.vue';
import CiResourceDetailsPage from 'ee/ci/catalog/components/pages/ci_resource_details_page.vue';
import CiResourceHeader from 'ee/ci/catalog/components/details/ci_resource_header.vue';
import CiResourceHeaderSkeletonLoader from 'ee/ci/catalog/components/details/ci_resource_header_skeleton_loader.vue';

import { createRouter } from 'ee/ci/catalog/router/index';
import { CI_RESOURCE_DETAILS_PAGE_NAME } from 'ee/ci/catalog/router/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { catalogSharedDataMock, catalogAdditionalDetailsMock } from '../../mock';

Vue.use(VueApollo);
Vue.use(VueRouter);

let router;

const defaultSharedData = { ...catalogSharedDataMock.data.ciCatalogResource };
const defaultAdditionalData = { ...catalogAdditionalDetailsMock.data.ciCatalogResource };

describe('CiResourceDetailsPage', () => {
  let wrapper;
  let sharedDataResponse;
  let additionalDataResponse;

  const defaultProps = {};

  const defaultProvide = {
    ciCatalogPath: '/ci/catalog/resources',
  };

  const findDetailsComponent = () => wrapper.findComponent(CiResourceDetails);
  const findHeaderComponent = () => wrapper.findComponent(CiResourceHeader);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findHeaderSkeletonLoader = () => wrapper.findComponent(CiResourceHeaderSkeletonLoader);

  const createComponent = ({ props = {} } = {}) => {
    const handlers = [
      [getCiCatalogResourceSharedData, sharedDataResponse],
      [getCiCatalogResourceDetails, additionalDataResponse],
    ];

    const mockApollo = createMockApollo(handlers, undefined, cacheConfig);

    wrapper = shallowMount(CiResourceDetailsPage, {
      router,
      apolloProvider: mockApollo,
      provide: {
        ...defaultProvide,
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        RouterView: true,
      },
    });
  };

  beforeEach(async () => {
    sharedDataResponse = jest.fn();
    additionalDataResponse = jest.fn();

    router = createRouter();
    await router.push({
      name: CI_RESOURCE_DETAILS_PAGE_NAME,
      params: { id: defaultSharedData.id },
    });
  });

  describe('when the app is loading', () => {
    describe('and shared data is pre-fetched', () => {
      beforeEach(() => {
        // By mocking a return value and not a promise, we skip the loading
        // to simulate having the pre-fetched query
        sharedDataResponse.mockReturnValueOnce(catalogSharedDataMock);
        additionalDataResponse.mockResolvedValue(catalogAdditionalDetailsMock);
        createComponent();
      });

      it('renders the header skeleton loader', () => {
        expect(findHeaderSkeletonLoader().exists()).toBe(false);
      });

      it('passes down the loading state to the header component', () => {
        sharedDataResponse.mockReturnValueOnce(catalogSharedDataMock);

        expect(findHeaderComponent().props()).toMatchObject({
          isLoadingDetails: true,
          isLoadingSharedData: false,
        });
      });
    });

    describe('and shared data is not pre-fetched', () => {
      beforeEach(() => {
        sharedDataResponse.mockResolvedValue(catalogSharedDataMock);
        additionalDataResponse.mockResolvedValue(catalogAdditionalDetailsMock);
        createComponent();
      });

      it('does not render the header skeleton', () => {
        expect(findHeaderSkeletonLoader().exists()).toBe(false);
      });

      it('passes all loading state to the header component as true', () => {
        expect(findHeaderComponent().props()).toMatchObject({
          isLoadingDetails: true,
          isLoadingSharedData: true,
        });
      });
    });
  });

  describe('and there are no resources', () => {
    beforeEach(async () => {
      const mockError = new Error('error');
      sharedDataResponse.mockRejectedValue(mockError);
      additionalDataResponse.mockRejectedValue(mockError);

      createComponent();
      await waitForPromises();
    });

    it('renders the empty state', () => {
      expect(findDetailsComponent().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().props('primaryButtonLink')).toBe(defaultProvide.ciCatalogPath);
    });
  });

  describe('when data has loaded', () => {
    beforeEach(async () => {
      sharedDataResponse.mockResolvedValue(catalogSharedDataMock);
      additionalDataResponse.mockResolvedValue(catalogAdditionalDetailsMock);
      createComponent();

      await waitForPromises();
    });

    it('does not render the header skeleton loader', () => {
      expect(findHeaderSkeletonLoader().exists()).toBe(false);
    });

    describe('Catalog header', () => {
      it('exists', () => {
        expect(findHeaderComponent().exists()).toBe(true);
      });

      it('passes expected props', () => {
        expect(findHeaderComponent().props()).toEqual({
          isLoadingDetails: false,
          isLoadingSharedData: false,
          openIssuesCount: defaultAdditionalData.openIssuesCount,
          openMergeRequestsCount: defaultAdditionalData.openMergeRequestsCount,
          pipelineStatus:
            defaultAdditionalData.versions.nodes[0].commit.pipelines.nodes[0].detailedStatus,
          resource: defaultSharedData,
        });
      });
    });

    describe('Catalog details', () => {
      it('exists', () => {
        expect(findDetailsComponent().exists()).toBe(true);
      });

      it('passes expected props', () => {
        expect(findDetailsComponent().props()).toEqual({
          resourceId: convertToGraphQLId(CI_CATALOG_RESOURCE_TYPE, defaultAdditionalData.id),
        });
      });
    });
  });
});
