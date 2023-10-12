import { GlProgressBar, GlAlert } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Cookies from '~/lib/utils/cookies';
import LearnGitlab from 'ee/pages/projects/learn_gitlab/components/learn_gitlab.vue';
import eventHub from '~/invite_members/event_hub';
import { INVITE_MODAL_OPEN_COOKIE } from 'ee/pages/projects/learn_gitlab/constants';
import { ON_CELEBRATION_TRACK_LABEL } from '~/invite_members/constants';
import eventHubNav from '~/super_sidebar/event_hub';
import { testActions, testSections, testProject } from './mock_data';

describe('Learn GitLab', () => {
  let wrapper;
  let sidebar;

  const createWrapper = () => {
    wrapper = mount(LearnGitlab, {
      propsData: {
        actions: testActions,
        sections: testSections,
        project: testProject,
      },
    });
  };

  describe('Initial rendering concerns', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders correctly', () => {
      expect(wrapper.element).toMatchSnapshot();
    });

    it('renders the progress percentage', () => {
      const text = wrapper.find('[data-testid="completion-percentage"]').text();

      expect(text).toBe('25% completed');
    });

    it('renders the progress bar with correct values', () => {
      const progressBar = wrapper.findComponent(GlProgressBar);

      expect(progressBar.vm.$attrs.value).toBe(3);
      expect(progressBar.vm.$attrs.max).toBe(12);
    });
  });

  describe('Invite Members Modal', () => {
    let spy;
    let cookieSpy;

    beforeEach(() => {
      spy = jest.spyOn(eventHub, '$emit');
      cookieSpy = jest.spyOn(Cookies, 'remove');
    });

    afterEach(() => {
      Cookies.remove(INVITE_MODAL_OPEN_COOKIE);
    });

    it('emits openModal', () => {
      Cookies.set(INVITE_MODAL_OPEN_COOKIE, true);

      createWrapper();

      expect(spy).toHaveBeenCalledWith('openModal', {
        mode: 'celebrate',
        source: ON_CELEBRATION_TRACK_LABEL,
      });
      expect(cookieSpy).toHaveBeenCalledWith(INVITE_MODAL_OPEN_COOKIE);
    });

    it('does not emit openModal when cookie is not set', () => {
      createWrapper();

      expect(spy).not.toHaveBeenCalled();
      expect(cookieSpy).toHaveBeenCalledWith(INVITE_MODAL_OPEN_COOKIE);
    });
  });

  describe('when the showSuccessfulInvitationsAlert event is fired', () => {
    const findAlert = () => wrapper.findComponent(GlAlert);

    beforeEach(() => {
      createWrapper();
      eventHub.$emit('showSuccessfulInvitationsAlert');
    });

    it('displays the successful invitations alert', () => {
      expect(findAlert().exists()).toBe(true);
    });

    it('displays a message with the project name', () => {
      expect(findAlert().text()).toBe(
        "Your team is growing! You've successfully invited new team members to the test-project project.",
      );
    });
  });

  describe('with sidebar percentage updates', () => {
    let spy;

    beforeEach(() => {
      spy = jest.spyOn(eventHubNav, '$emit');
    });

    it('modifies the sidebar percentage', () => {
      sidebar = document.createElement('div');
      sidebar.innerHTML = `
    <div class="sidebar-top-level-items">
      <div class="active">
        <div class="count"></div>
      </div>
    </div>
    `;
      document.body.appendChild(sidebar);
      createWrapper();

      eventHub.$emit('showSuccessfulInvitationsAlert');

      expect(sidebar.textContent.trim()).toBe('25%');
      expect(spy).not.toHaveBeenCalled();

      sidebar.remove();
    });

    it('emits updatePillValue event for super sidebar', () => {
      createWrapper();

      eventHub.$emit('showSuccessfulInvitationsAlert');

      expect(spy).toHaveBeenCalledWith('updatePillValue', {
        value: '25%',
        itemId: 'learn_gitlab',
      });
    });
  });
});
