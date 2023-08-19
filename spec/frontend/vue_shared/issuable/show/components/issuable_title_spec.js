import { GlIcon, GlBadge, GlButton, GlIntersectionObserver } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';

import IssuableTitle from '~/vue_shared/issuable/show/components/issuable_title.vue';

import { mockIssuableShowProps, mockIssuable } from '../mock_data';

const issuableTitleProps = {
  issuable: mockIssuable,
  ...mockIssuableShowProps,
};

const createComponent = (propsData = issuableTitleProps) =>
  shallowMount(IssuableTitle, {
    propsData,
    stubs: {
      transition: true,
    },
    slots: {
      'status-badge': 'Open',
    },
    directives: {
      GlTooltip: createMockDirective('gl-tooltip'),
    },
  });

describe('IssuableTitle', () => {
  let wrapper;

  const findStickyHeader = () => wrapper.findComponent('[data-testid="header"]');

  beforeEach(() => {
    wrapper = createComponent();
  });

  describe('methods', () => {
    describe('handleTitleAppear', () => {
      it('sets value of `stickyTitleVisible` prop to false', async () => {
        wrapper.findComponent(GlIntersectionObserver).vm.$emit('appear');
        await nextTick();

        expect(findStickyHeader().exists()).toBe(false);
      });
    });

    describe('handleTitleDisappear', () => {
      it('sets value of `stickyTitleVisible` prop to true', async () => {
        wrapper.findComponent(GlIntersectionObserver).vm.$emit('disappear');
        await nextTick();

        expect(findStickyHeader().exists()).toBe(true);
      });
    });
  });

  describe('template', () => {
    it('renders issuable title', async () => {
      const wrapperWithTitle = createComponent({
        ...mockIssuableShowProps,
        issuable: {
          ...mockIssuable,
          titleHtml: '<b>Sample</b> title',
        },
      });

      await nextTick();
      const titleEl = wrapperWithTitle.find('[data-testid="issuable-title"]');

      expect(titleEl.exists()).toBe(true);
      expect(titleEl.html()).toBe(
        '<h1 dir="auto" data-testid="issuable-title" class="title gl-font-size-h-display"><b>Sample</b> title</h1>',
      );

      wrapperWithTitle.destroy();
    });

    it('renders edit button', () => {
      const editButtonEl = wrapper.findComponent(GlButton);
      const tooltip = getBinding(editButtonEl.element, 'gl-tooltip');

      expect(editButtonEl.exists()).toBe(true);
      expect(editButtonEl.props('icon')).toBe('pencil');
      expect(editButtonEl.attributes('title')).toBe('Edit title and description');
      expect(tooltip).toBeDefined();
    });

    it('renders sticky header when `stickyTitleVisible` prop is true', async () => {
      wrapper.findComponent(GlIntersectionObserver).vm.$emit('disappear');
      await nextTick();

      const stickyHeaderEl = findStickyHeader();

      expect(stickyHeaderEl.exists()).toBe(true);
      expect(stickyHeaderEl.findComponent(GlBadge).props('variant')).toBe('success');
      expect(stickyHeaderEl.findComponent(GlIcon).props('name')).toBe(
        issuableTitleProps.statusIcon,
      );
      expect(stickyHeaderEl.text()).toContain('Open');
      expect(stickyHeaderEl.text()).toContain(issuableTitleProps.issuable.title);
    });
  });
});
