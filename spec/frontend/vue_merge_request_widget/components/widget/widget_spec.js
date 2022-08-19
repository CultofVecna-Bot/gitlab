import { nextTick } from 'vue';
import * as Sentry from '@sentry/browser';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import StatusIcon from '~/vue_merge_request_widget/components/extensions/status_icon.vue';
import Widget from '~/vue_merge_request_widget/components/widget/widget.vue';

describe('MR Widget', () => {
  let wrapper;

  const findStatusIcon = () => wrapper.findComponent(StatusIcon);
  const findExpandedSection = () => wrapper.findByTestId('widget-extension-collapsed-section');
  const findToggleButton = () => wrapper.findByTestId('toggle-button');

  const createComponent = ({ propsData, slots } = {}) => {
    wrapper = shallowMountExtended(Widget, {
      propsData: {
        isCollapsible: false,
        loadingText: 'Loading widget',
        widgetName: 'MyWidget',
        value: {
          collapsed: null,
          expanded: null,
        },
        ...propsData,
      },
      slots,
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('on mount', () => {
    it('fetches collapsed', async () => {
      const fetchCollapsedData = jest
        .fn()
        .mockReturnValue(Promise.resolve({ headers: {}, status: 200, data: {} }));

      createComponent({ propsData: { fetchCollapsedData } });
      await waitForPromises();
      expect(fetchCollapsedData).toHaveBeenCalled();
      expect(wrapper.vm.error).toBe(null);
    });

    it('sets the error text when fetch method fails', async () => {
      const fetchCollapsedData = jest.fn().mockReturnValue(() => Promise.reject());
      createComponent({ propsData: { fetchCollapsedData } });
      await waitForPromises();
      expect(wrapper.findByText('Failed to load').exists()).toBe(true);
      expect(findStatusIcon().props()).toMatchObject({ iconName: 'failed', isLoading: false });
    });

    it('displays loading icon until request is made and then displays status icon when the request is complete', async () => {
      const fetchCollapsedData = jest
        .fn()
        .mockReturnValue(Promise.resolve({ headers: {}, status: 200, data: {} }));

      createComponent({ propsData: { fetchCollapsedData, statusIconName: 'warning' } });

      // Let on mount be called
      await nextTick();

      expect(findStatusIcon().props('isLoading')).toBe(true);

      // Wait until `fetchCollapsedData` is resolved
      await waitForPromises();

      expect(findStatusIcon().props('isLoading')).toBe(false);
      expect(findStatusIcon().props('iconName')).toBe('warning');
    });

    it('displays the loading text', async () => {
      const fetchCollapsedData = jest.fn().mockReturnValue(() => Promise.reject());
      createComponent({ propsData: { fetchCollapsedData, statusIconName: 'warning' } });
      expect(wrapper.text()).not.toContain('Loading');
      await nextTick();
      expect(wrapper.text()).toContain('Loading');
    });
  });

  describe('fetch', () => {
    it('sets the data.collapsed property after a successfull call - multiPolling: false', async () => {
      const mockData = { headers: {}, status: 200, data: { vulnerabilities: [] } };
      createComponent({ propsData: { fetchCollapsedData: async () => mockData } });
      await waitForPromises();
      expect(wrapper.emitted('input')[0][0]).toEqual({ collapsed: mockData.data, expanded: null });
    });

    it('sets the data.collapsed property after a successfull call - multiPolling: true', async () => {
      const mockData1 = { headers: {}, status: 200, data: { vulnerabilities: [{ vuln: 1 }] } };
      const mockData2 = { headers: {}, status: 200, data: { vulnerabilities: [{ vuln: 2 }] } };

      createComponent({
        propsData: {
          multiPolling: true,
          fetchCollapsedData: () => [
            () => Promise.resolve(mockData1),
            () => Promise.resolve(mockData2),
          ],
        },
      });

      await waitForPromises();

      expect(wrapper.emitted('input')[0][0]).toEqual({
        collapsed: [mockData1.data, mockData2.data],
        expanded: null,
      });
    });

    it('calls sentry when failed', async () => {
      const error = new Error('Something went wrong');
      jest.spyOn(Sentry, 'captureException').mockImplementation();
      createComponent({
        propsData: {
          fetchCollapsedData: () => Promise.reject(error),
        },
      });
      await waitForPromises();
      expect(wrapper.emitted('input')).toBeUndefined();
      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });

  describe('content', () => {
    it('displays summary property when summary slot is not provided', () => {
      createComponent({
        propsData: {
          summary: 'Hello world',
          fetchCollapsedData: () => Promise.resolve(),
        },
      });

      expect(wrapper.findByTestId('widget-extension-top-level-summary').text()).toBe('Hello world');
    });

    it.todo('displays content property when content slot is not provided');

    it('displays the summary slot when provided', () => {
      createComponent({
        propsData: {
          fetchCollapsedData: () => Promise.resolve(),
        },
        slots: {
          summary: '<b>More complex summary</b>',
        },
      });

      expect(wrapper.findByTestId('widget-extension-top-level-summary').text()).toBe(
        'More complex summary',
      );
    });
  });

  describe('handle collapse toggle', () => {
    it('displays the toggle button correctly', () => {
      createComponent({
        propsData: {
          isCollapsible: true,
          fetchCollapsedData: () => Promise.resolve(),
        },
        slots: {
          content: '<b>More complex content</b>',
        },
      });

      expect(findToggleButton().attributes('title')).toBe('Show details');
      expect(findToggleButton().attributes('aria-label')).toBe('Show details');
    });

    it('does not display the content slot until toggle is clicked', async () => {
      createComponent({
        propsData: {
          isCollapsible: true,
          fetchCollapsedData: () => Promise.resolve(),
        },
        slots: {
          content: '<b>More complex content</b>',
        },
      });

      expect(findExpandedSection().exists()).toBe(false);
      findToggleButton().vm.$emit('click');
      await nextTick();
      expect(findExpandedSection().text()).toBe('More complex content');
    });

    it('does not display the toggle button if isCollapsible is false', () => {
      createComponent({
        propsData: {
          isCollapsible: false,
          fetchCollapsedData: () => Promise.resolve(),
        },
      });

      expect(findToggleButton().exists()).toBe(false);
    });
  });
});
