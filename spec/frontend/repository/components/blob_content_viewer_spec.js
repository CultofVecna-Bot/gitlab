import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import BlobContent from '~/blob/components/blob_content.vue';
import BlobHeader from '~/blob/components/blob_header.vue';
import BlobContentViewer from '~/repository/components/blob_content_viewer.vue';

let wrapper;
const simpleMockData = {
  name: 'some_file.js',
  size: 123,
  rawSize: 123,
  rawTextBlob: 'raw content',
  type: 'text',
  fileType: 'text',
  tooLarge: false,
  path: 'some_file.js',
  editBlobPath: 'some_file.js/edit',
  ideEditPath: 'some_file.js/ide/edit',
  storedExternally: false,
  rawPath: 'some_file.js',
  externalStorageUrl: 'some_file.js',
  replacePath: 'some_file.js/replace',
  deletePath: 'some_file.js/delete',
  canLock: true,
  isLocked: false,
  lockLink: 'some_file.js/lock',
  canModifyBlob: true,
  forkPath: 'some_file.js/fork',
  simpleViewer: {
    fileType: 'text',
    tooLarge: false,
    type: 'simple',
    renderError: null,
  },
  richViewer: null,
};
const richMockData = {
  ...simpleMockData,
  richViewer: {
    fileType: 'markup',
    tooLarge: false,
    type: 'rich',
    renderError: null,
  },
};

function factory({ props = {}, mockData = {} } = {}, loading = false) {
  wrapper = shallowMount(BlobContentViewer, {
    propsData: {
      path: 'some_file.js',
      projectPath: 'some/path',
      hasRichViewer: false,
      ...props,
    },
    mocks: {
      $apollo: {
        queries: {
          project: {
            loading,
          },
        },
      },
    },
  });

  wrapper.setData({ blobInfo: mockData });
}

describe('Blob content viewer component', () => {
  const findLoadingIcon = () => wrapper.find(GlLoadingIcon);
  const findBlobHeader = () => wrapper.find(BlobHeader);
  const findBlobContent = () => wrapper.find(BlobContent);

  beforeEach(() => {
    factory({ mockData: simpleMockData });
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('renders a GlLoadingIcon component', () => {
    factory({ mockData: simpleMockData }, true);

    expect(findLoadingIcon().exists()).toBe(true);
  });

  describe('simple viewer', () => {
    it('renders a BlobHeader component', () => {
      expect(findBlobHeader().props('activeViewerType')).toEqual('simple');
      expect(findBlobHeader().props('hasRenderError')).toEqual(false);
      expect(findBlobHeader().props('hideViewerSwitcher')).toEqual(true);
      expect(findBlobHeader().props('blob')).toEqual(simpleMockData);
    });

    it('renders a BlobContent component', () => {
      expect(findBlobContent().props('loading')).toEqual(false);
      expect(findBlobContent().props('content')).toEqual('raw content');
      expect(findBlobContent().props('isRawContent')).toBe(true);
      expect(findBlobContent().props('activeViewer')).toEqual({
        fileType: 'text',
        tooLarge: false,
        type: 'simple',
        renderError: null,
      });
    });
  });

  describe('rich viewer', () => {
    beforeEach(() => {
      factory({ props: { hasRichViewer: true }, mockData: richMockData });
    });

    it('renders a BlobHeader component', () => {
      expect(findBlobHeader().props('activeViewerType')).toEqual('rich');
      expect(findBlobHeader().props('hasRenderError')).toEqual(false);
      expect(findBlobHeader().props('hideViewerSwitcher')).toEqual(false);
      expect(findBlobHeader().props('blob')).toEqual(richMockData);
    });

    it('renders a BlobContent component', () => {
      expect(findBlobContent().props('loading')).toEqual(false);
      expect(findBlobContent().props('content')).toEqual('raw content');
      expect(findBlobContent().props('isRawContent')).toBe(true);
      expect(findBlobContent().props('activeViewer')).toEqual({
        fileType: 'markup',
        tooLarge: false,
        type: 'rich',
        renderError: null,
      });
    });

    it('updates viewer type when viewer changed is clicked', async () => {
      expect(findBlobContent().props('activeViewer')).toEqual(
        expect.objectContaining({
          type: 'rich',
        }),
      );
      expect(findBlobHeader().props('activeViewerType')).toEqual('rich');

      findBlobHeader().vm.$emit('viewer-changed', 'simple');
      await wrapper.vm.$nextTick();

      expect(findBlobHeader().props('activeViewerType')).toEqual('simple');
      expect(findBlobContent().props('activeViewer')).toEqual(
        expect.objectContaining({
          type: 'simple',
        }),
      );
    });
  });
});
