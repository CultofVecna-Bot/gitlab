import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import CustomEmailForm from '~/projects/settings_service_desk/components/custom_email_form.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { I18N_FORM_FORWARDING_CLIPBOARD_BUTTON_TITLE } from '~/projects/settings_service_desk/custom_email_constants';

describe('CustomEmailForm', () => {
  let wrapper;

  const defaultProps = {
    incomingEmail: 'incoming@example.com',
    submitting: false,
  };

  const findForm = () => wrapper.find('form');
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);
  const findInputByTestId = (testId) => wrapper.findByTestId(testId).find('input');
  const findCustomEmailInput = () => findInputByTestId('form-custom-email');
  const findSmtpAddressInput = () => findInputByTestId('form-smtp-address');
  const findSmtpPortInput = () => findInputByTestId('form-smtp-port');
  const findSmtpUsernameInput = () => findInputByTestId('form-smtp-username');
  const findSmtpPasswordInput = () => findInputByTestId('form-smtp-password');
  const findSubmit = () => wrapper.findByTestId('form-submit');

  const clickButtonAndExpectNoSubmitEvent = async () => {
    await nextTick();
    findForm().trigger('submit');

    expect(findSubmit().find('button').attributes('disabled')).toBeDefined();
    expect(wrapper.emitted('submit')).toEqual(undefined);
  };

  const createWrapper = (props = {}) => {
    wrapper = extendedWrapper(mount(CustomEmailForm, { propsData: { ...defaultProps, ...props } }));
  };

  it('renders a copy to clipboard button', () => {
    createWrapper();

    expect(findClipboardButton().exists()).toBe(true);
    expect(findClipboardButton().props()).toEqual(
      expect.objectContaining({
        title: I18N_FORM_FORWARDING_CLIPBOARD_BUTTON_TITLE,
        text: defaultProps.incomingEmail,
      }),
    );
  });

  it('form inputs are disabled when submitting', () => {
    createWrapper({ submitting: true });

    expect(findCustomEmailInput().attributes('disabled')).toBeDefined();
    expect(findSmtpAddressInput().attributes('disabled')).toBeDefined();
    expect(findSmtpPortInput().attributes('disabled')).toBeDefined();
    expect(findSmtpUsernameInput().attributes('disabled')).toBeDefined();
    expect(findSmtpPasswordInput().attributes('disabled')).toBeDefined();
    expect(findSubmit().props('loading')).toBe(true);
  });

  describe('form validation and submit event', () => {
    it('is invalid when form inputs are empty', async () => {
      createWrapper();

      await nextTick();
      findForm().trigger('submit');

      expect(wrapper.emitted('submit')).toEqual(undefined);
    });

    describe('with inputs set', () => {
      beforeEach(() => {
        createWrapper();

        findCustomEmailInput().setValue('user@example.com');
        findCustomEmailInput().trigger('change');

        findSmtpAddressInput().setValue('smtp.example.com');
        findSmtpAddressInput().trigger('change');

        findSmtpPortInput().setValue('587');
        findSmtpPortInput().trigger('change');

        findSmtpUsernameInput().setValue('user@example.com');
        findSmtpUsernameInput().trigger('change');

        findSmtpPasswordInput().setValue('supersecret');
        findSmtpPasswordInput().trigger('change');
      });

      it('is invalid when malformed email provided', async () => {
        findCustomEmailInput().setValue('userexample.com');
        findCustomEmailInput().trigger('change');

        await clickButtonAndExpectNoSubmitEvent();
        expect(findCustomEmailInput().classes()).toContain('is-invalid');
      });

      it('is invalid when email is not set', async () => {
        findCustomEmailInput().setValue('');
        findCustomEmailInput().trigger('change');

        await clickButtonAndExpectNoSubmitEvent();
        expect(findCustomEmailInput().classes()).toContain('is-invalid');
      });

      it('is invalid when smtp address is not set', async () => {
        findSmtpAddressInput().setValue('');
        findSmtpAddressInput().trigger('change');

        await clickButtonAndExpectNoSubmitEvent();
        expect(findSmtpAddressInput().classes()).toContain('is-invalid');
      });

      it('is invalid when smtp port is not set', async () => {
        findSmtpPortInput().setValue('');
        findSmtpPortInput().trigger('change');

        await clickButtonAndExpectNoSubmitEvent();
        expect(findSmtpPortInput().classes()).toContain('is-invalid');
      });

      it('is invalid when smtp port is not an integer', async () => {
        findSmtpPortInput().setValue('20m2');
        findSmtpPortInput().trigger('change');

        await clickButtonAndExpectNoSubmitEvent();
        expect(findSmtpPortInput().classes()).toContain('is-invalid');
      });

      it('is invalid when smtp port is 0', async () => {
        findSmtpPortInput().setValue('0');
        findSmtpPortInput().trigger('change');

        await clickButtonAndExpectNoSubmitEvent();
        expect(findSmtpPortInput().classes()).toContain('is-invalid');
      });

      it('is invalid when smtp username is not set', async () => {
        findSmtpUsernameInput().setValue('');
        findSmtpUsernameInput().trigger('change');

        await clickButtonAndExpectNoSubmitEvent();
        expect(findSmtpUsernameInput().classes()).toContain('is-invalid');
      });

      it('is invalid when password is too short', async () => {
        findSmtpPasswordInput().setValue('2short');
        findSmtpPasswordInput().trigger('change');

        await clickButtonAndExpectNoSubmitEvent();
        expect(findSmtpPasswordInput().classes()).toContain('is-invalid');
      });

      it('is invalid when password is not set', async () => {
        findSmtpPasswordInput().setValue('');
        findSmtpPasswordInput().trigger('change');

        await clickButtonAndExpectNoSubmitEvent();
        expect(findSmtpPasswordInput().classes()).toContain('is-invalid');
      });

      it('sets smtpUsername automatically when empty based on customEmail', async () => {
        const email = 'support@example.com';

        findSmtpUsernameInput().setValue('');
        findSmtpUsernameInput().trigger('change');

        findCustomEmailInput().setValue(email);
        findCustomEmailInput().trigger('change');

        await nextTick();

        expect(findSmtpUsernameInput().element.value).toBe(email);
        expect(wrapper.html()).not.toContain('is-invalid');
      });

      it('is valid and emits submit event with form data', async () => {
        await nextTick();

        expect(wrapper.html()).not.toContain('is-invalid');

        findForm().trigger('submit');

        expect(wrapper.emitted('submit')).toEqual([
          [
            {
              custom_email: 'user@example.com',
              smtp_address: 'smtp.example.com',
              smtp_password: 'supersecret',
              smtp_port: '587',
              smtp_username: 'user@example.com',
            },
          ],
        ]);
      });
    });
  });
});
