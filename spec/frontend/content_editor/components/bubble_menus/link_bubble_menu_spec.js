import { GlLink, GlForm } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import LinkBubbleMenu from '~/content_editor/components/bubble_menus/link_bubble_menu.vue';
import EditorStateObserver from '~/content_editor/components/editor_state_observer.vue';
import eventHubFactory from '~/helpers/event_hub_factory';
import BubbleMenu from '~/content_editor/components/bubble_menus/bubble_menu.vue';
import { stubComponent } from 'helpers/stub_component';
import Link from '~/content_editor/extensions/link';
import { createTestEditor } from '../../test_utils';

const createFakeEvent = () => ({ preventDefault: jest.fn(), stopPropagation: jest.fn() });

describe('content_editor/components/bubble_menus/link_bubble_menu', () => {
  let wrapper;
  let tiptapEditor;
  let contentEditor;
  let eventHub;

  const buildEditor = () => {
    tiptapEditor = createTestEditor({ extensions: [Link] });
    contentEditor = { resolveUrl: jest.fn() };
    eventHub = eventHubFactory();
  };

  const buildWrapper = () => {
    wrapper = mountExtended(LinkBubbleMenu, {
      provide: {
        tiptapEditor,
        contentEditor,
        eventHub,
      },
      stubs: {
        BubbleMenu: stubComponent(BubbleMenu),
      },
    });
  };

  const showMenu = () => {
    wrapper.findComponent(BubbleMenu).vm.$emit('show');
    return nextTick();
  };

  const buildWrapperAndDisplayMenu = () => {
    buildWrapper();

    return showMenu();
  };

  const findBubbleMenu = () => wrapper.findComponent(BubbleMenu);
  const findLink = () => wrapper.findComponent(GlLink);
  const findEditorStateObserver = () => wrapper.findComponent(EditorStateObserver);
  const findEditLinkButton = () => wrapper.findByTestId('edit-link');

  const expectLinkButtonsToExist = (exist = true) => {
    expect(wrapper.findComponent(GlLink).exists()).toBe(exist);
    expect(wrapper.findByTestId('copy-link-url').exists()).toBe(exist);
    expect(wrapper.findByTestId('edit-link').exists()).toBe(exist);
    expect(wrapper.findByTestId('remove-link').exists()).toBe(exist);
  };

  beforeEach(async () => {
    buildEditor();

    tiptapEditor
      .chain()
      .insertContent(
        'Download <a href="/path/to/project/-/wikis/uploads/my_file.pdf" data-canonical-src="uploads/my_file.pdf" title="Click here to download">PDF File</a>',
      )
      .setTextSelection(14) // put cursor in the middle of the link
      .run();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('renders bubble menu component', async () => {
    await buildWrapperAndDisplayMenu();

    expect(findBubbleMenu().classes()).toEqual(['gl-shadow', 'gl-rounded-base', 'gl-bg-white']);
  });

  it('shows a clickable link to the URL in the link node', async () => {
    await buildWrapperAndDisplayMenu();

    expect(findLink().attributes()).toEqual(
      expect.objectContaining({
        href: '/path/to/project/-/wikis/uploads/my_file.pdf',
        'aria-label': 'uploads/my_file.pdf',
        title: 'uploads/my_file.pdf',
        target: '_blank',
      }),
    );
    expect(findLink().text()).toBe('uploads/my_file.pdf');
  });

  it('updates the bubble menu state when @selectionUpdate event is triggered', async () => {
    const linkUrl = 'https://gitlab.com';

    await buildWrapperAndDisplayMenu();

    expect(findLink().attributes()).toEqual(
      expect.objectContaining({
        href: '/path/to/project/-/wikis/uploads/my_file.pdf',
      }),
    );

    tiptapEditor
      .chain()
      .setContent(
        `Link to <a href="${linkUrl}" data-canonical-src="${linkUrl}" title="Click here to download">GitLab</a>`,
      )
      .setTextSelection(11)
      .run();

    findEditorStateObserver().vm.$emit('selectionUpdate');

    await nextTick();

    expect(findLink().attributes()).toEqual(
      expect.objectContaining({
        href: linkUrl,
      }),
    );
  });

  describe('when the selection changes within the same link', () => {
    it('does not update the bubble menu state', async () => {
      await buildWrapperAndDisplayMenu();

      await findEditLinkButton().trigger('click');

      expect(wrapper.findComponent(GlForm).exists()).toBe(true);

      tiptapEditor.commands.setTextSelection(13);

      findEditorStateObserver().vm.$emit('selectionUpdate');

      await nextTick();

      expect(wrapper.findComponent(GlForm).exists()).toBe(true);
    });
  });

  it('cleans bubble menu state when hidden event is triggered', async () => {
    await buildWrapperAndDisplayMenu();

    expect(findLink().attributes()).toEqual(
      expect.objectContaining({
        href: '/path/to/project/-/wikis/uploads/my_file.pdf',
      }),
    );

    findBubbleMenu().vm.$emit('hidden');

    await nextTick();

    expect(findLink().attributes()).toEqual(
      expect.objectContaining({
        href: '#',
      }),
    );
    expect(findLink().text()).toEqual('');
  });

  describe('copy button', () => {
    it('copies the canonical link to clipboard', async () => {
      await buildWrapperAndDisplayMenu();

      jest.spyOn(navigator.clipboard, 'writeText');

      await wrapper.findByTestId('copy-link-url').vm.$emit('click');

      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('uploads/my_file.pdf');
    });
  });

  describe('remove link button', () => {
    it('removes the link', async () => {
      await buildWrapperAndDisplayMenu();
      await wrapper.findByTestId('remove-link').vm.$emit('click');

      expect(tiptapEditor.getHTML()).toBe('<p>Download PDF File</p>');
    });
  });

  describe('for a placeholder link', () => {
    beforeEach(async () => {
      tiptapEditor
        .chain()
        .clearContent()
        .insertContent('Dummy link')
        .selectAll()
        .setLink({ href: '' })
        .setTextSelection(4)
        .run();

      await buildWrapperAndDisplayMenu();
    });

    it('directly opens the edit form for a placeholder link', async () => {
      expectLinkButtonsToExist(false);

      expect(wrapper.findComponent(GlForm).exists()).toBe(true);
    });

    it('removes the link on clicking apply (if no change)', async () => {
      await wrapper.findComponent(GlForm).vm.$emit('submit', createFakeEvent());

      expect(tiptapEditor.getHTML()).toBe('<p>Dummy link</p>');
    });

    it('removes the link on clicking cancel', async () => {
      await wrapper.findByTestId('cancel-link').vm.$emit('click');

      expect(tiptapEditor.getHTML()).toBe('<p>Dummy link</p>');
    });
  });

  describe('edit button', () => {
    let linkHrefInput;
    let linkTitleInput;

    beforeEach(async () => {
      await buildWrapperAndDisplayMenu();
      await wrapper.findByTestId('edit-link').vm.$emit('click');

      linkHrefInput = wrapper.findByTestId('link-href');
      linkTitleInput = wrapper.findByTestId('link-title');
    });

    it('hides the link and copy/edit/remove link buttons', async () => {
      expectLinkButtonsToExist(false);
    });

    it('shows a form to edit the link', () => {
      expect(wrapper.findComponent(GlForm).exists()).toBe(true);

      expect(linkHrefInput.element.value).toBe('uploads/my_file.pdf');
      expect(linkTitleInput.element.value).toBe('Click here to download');
    });

    it('extends selection to select the entire link', () => {
      const { from, to } = tiptapEditor.state.selection;

      expect(from).toBe(10);
      expect(to).toBe(18);
    });

    describe('after making changes in the form and clicking apply', () => {
      beforeEach(async () => {
        linkHrefInput.setValue('https://google.com');
        linkTitleInput.setValue('Search Google');

        contentEditor.resolveUrl.mockResolvedValue('https://google.com');

        await wrapper.findComponent(GlForm).vm.$emit('submit', createFakeEvent());
      });

      it('updates prosemirror doc with new link', async () => {
        expect(tiptapEditor.getHTML()).toBe(
          '<p>Download <a target="_blank" rel="noopener noreferrer nofollow" href="https://google.com" title="Search Google">PDF File</a></p>',
        );
      });

      it('updates the link in the bubble menu', () => {
        const link = wrapper.findComponent(GlLink);
        expect(link.attributes()).toEqual(
          expect.objectContaining({
            href: 'https://google.com',
            'aria-label': 'https://google.com',
            title: 'https://google.com',
            target: '_blank',
          }),
        );
        expect(link.text()).toBe('https://google.com');
      });
    });

    describe('after making changes in the form and clicking cancel', () => {
      beforeEach(async () => {
        linkHrefInput.setValue('https://google.com');
        linkTitleInput.setValue('Search Google');

        await wrapper.findByTestId('cancel-link').vm.$emit('click');
      });

      it('hides the form and shows the copy/edit/remove link buttons', () => {
        expectLinkButtonsToExist();
      });

      it('resets the form with old values of the link from prosemirror', async () => {
        // click edit once again to show the form back
        await wrapper.findByTestId('edit-link').vm.$emit('click');

        linkHrefInput = wrapper.findByTestId('link-href');
        linkTitleInput = wrapper.findByTestId('link-title');

        expect(linkHrefInput.element.value).toBe('uploads/my_file.pdf');
        expect(linkTitleInput.element.value).toBe('Click here to download');
      });
    });
  });
});
