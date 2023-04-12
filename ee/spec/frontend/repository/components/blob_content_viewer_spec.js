import Vue from 'vue';
import Vuex from 'vuex';
import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import AiGenie from 'ee_component/ai/components/ai_genie.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BlobButtonGroup from '~/repository/components/blob_button_group.vue';
import BlobContentViewer from '~/repository/components/blob_content_viewer.vue';
import blobInfoQuery from 'shared_queries/repository/blob_info.query.graphql';
import projectInfoQuery from '~/repository/queries/project_info.query.graphql';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  simpleViewerMock,
  projectMock,
  userPermissionsMock,
  propsMock,
  refMock,
} from 'jest/repository/mock_data';

jest.mock('~/lib/utils/common_utils');
Vue.use(VueRouter);
const router = new VueRouter();
const mockAxios = new MockAdapter(axios);

let wrapper;
let mockResolver;

Vue.use(VueApollo);

const createMockStore = () =>
  new Vuex.Store({ actions: { fetchData: jest.fn, setInitialData: jest.fn() } });

const createComponent = async (mockData = {}) => {
  const {
    blob = simpleViewerMock,
    empty = projectMock.repository.empty,
    pushCode = userPermissionsMock.pushCode,
    forkProject = userPermissionsMock.forkProject,
    downloadCode = userPermissionsMock.downloadCode,
    createMergeRequestIn = userPermissionsMock.createMergeRequestIn,
    isBinary,
    path = propsMock.projectPath,
    glFeatures = {},
  } = mockData;

  const project = {
    ...projectMock,
    userPermissions: {
      pushCode,
      forkProject,
      downloadCode,
      createMergeRequestIn,
    },
    repository: {
      __typename: 'Repository',
      empty,
      blobs: { __typename: 'RepositoryBlobConnection', nodes: [blob] },
    },
  };

  mockResolver = jest.fn().mockResolvedValue({
    data: { isBinary, project },
  });

  const fakeApollo = createMockApollo([
    [blobInfoQuery, mockResolver],
    [projectInfoQuery, mockResolver],
  ]);

  wrapper = mountExtended(BlobContentViewer, {
    store: createMockStore(),
    router,
    apolloProvider: fakeApollo,
    propsData: {
      ...propsMock,
      path,
    },
    mixins: [{ data: () => ({ ref: refMock }) }],
    provide: {
      targetBranch: 'test',
      originalBranch: 'test',
      glFeatures,
    },
  });

  await waitForPromises();
};

const findAiGenie = () => wrapper.findComponent(AiGenie);

describe('Blob content viewer component', () => {
  const findBlobButtonGroup = () => wrapper.findComponent(BlobButtonGroup);

  beforeEach(() => {
    gon.features = { highlightJs: true };
    isLoggedIn.mockReturnValue(true);
  });

  afterEach(() => {
    mockAxios.reset();
  });

  describe('AI Genie component', () => {
    const prepGonAndLoad = async (ffEnabled = true, licenseEnabled = true) => {
      const glFeatures = {
        explainCodeSnippet: ffEnabled,
        explainCode: licenseEnabled,
      };

      createComponent({ glFeatures });
      await waitForPromises();
    };

    beforeEach(() => {
      window.gon = {};
    });

    afterEach(() => {
      window.gon = {};
    });

    it.each`
      prefix        | ffEnabled | licenseEnabled | shouldRender
      ${'does not'} | ${false}  | ${false}       | ${false}
      ${'does not'} | ${true}   | ${false}       | ${false}
      ${'does not'} | ${false}  | ${true}        | ${false}
      ${'does'}     | ${true}   | ${true}        | ${true}
    `(
      '$prefix render the AI Genie component when licensed feature is $licenseEnabled and feature flag is $ffEnabled',
      async ({ ffEnabled, licenseEnabled, shouldRender }) => {
        await prepGonAndLoad(ffEnabled, licenseEnabled);
        expect(findAiGenie().exists()).toBe(shouldRender);
      },
    );

    it('sets correct props on the AI Genie component', async () => {
      await prepGonAndLoad();
      expect(findAiGenie().props('containerId')).toBe('fileHolder');
      expect(findAiGenie().props('filePath')).toBe(propsMock.projectPath);
    });
  });

  describe('BlobHeader action slot', () => {
    describe('BlobButtonGroup', () => {
      const {
        repository: { empty },
      } = projectMock;

      it.each`
        canPushCode | canDownloadCode | username   | canLock
        ${true}     | ${true}         | ${'root'}  | ${true}
        ${false}    | ${true}         | ${'root'}  | ${false}
        ${true}     | ${false}        | ${'root'}  | ${false}
        ${true}     | ${true}         | ${'peter'} | ${false}
      `(
        'passes the correct lock states',
        async ({ canPushCode, canDownloadCode, username, canLock }) => {
          gon.current_username = username;

          await createComponent({
            pushCode: canPushCode,
            downloadCode: canDownloadCode,
            empty,
            path: 'locked_file.js',
          });

          expect(findBlobButtonGroup().props('canLock')).toBe(canLock);
        },
      );
    });
  });
});
