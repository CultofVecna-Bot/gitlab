import { shallowMount } from '@vue/test-utils';
import DisableTwoFactorDropdownItem from 'ee/members/components/action_dropdowns/disable_two_factor_dropdown_item.vue';
import LdapOverrideDropdownItem from 'ee/members/components/ldap/ldap_override_dropdown_item.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { member } from 'jest/members/mock_data';
import { sprintf } from '~/locale';
import UserActionDropdown from '~/members/components/action_dropdowns/user_action_dropdown.vue';
import { I18N } from '~/members/components/action_dropdowns/constants';
import { MEMBER_TYPES } from '~/members/constants';

describe('UserActionDropdown', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(UserActionDropdown, {
      provide: {
        namespace: MEMBER_TYPES.user,
      },
      propsData: {
        member,
        isCurrentUser: false,
        isInvitedUser: false,
        ...propsData,
      },
    });

    return waitForPromises();
  };

  const findDisableTwoFactorDropdownItem = () =>
    wrapper.findComponent(DisableTwoFactorDropdownItem);
  const findLdapOverrideDropdownItem = () => wrapper.findComponent(LdapOverrideDropdownItem);

  describe('when `canDisableTwoFactor` permission', () => {
    describe('is `true`', () => {
      it('renders the dropdown item', async () => {
        await createComponent({
          permissions: { canDisableTwoFactor: true },
        });

        expect(findDisableTwoFactorDropdownItem().props('modalMessage')).toBe(
          sprintf(I18N.confirmDisableTwoFactor, { userName: member.user.username }),
        );
      });
    });

    describe('is `false`', () => {
      it('does not render the dropdown item', async () => {
        await createComponent({
          permissions: { canDisableTwoFactor: false },
        });

        expect(findDisableTwoFactorDropdownItem().exists()).toBe(false);
      });
    });
  });

  describe('when member has `canOverride` permissions', () => {
    describe('when member is not overridden', () => {
      it('renders LDAP override dropdown item with correct text', async () => {
        await createComponent({
          permissions: { canOverride: true },
          member: {
            ...member,
            isOverridden: false,
          },
        });

        const ldapOverrideDropdownItem = findLdapOverrideDropdownItem();
        expect(ldapOverrideDropdownItem.exists()).toBe(true);
        expect(ldapOverrideDropdownItem.html()).toContain(I18N.editPermissions);
      });
    });

    describe('when member is overridden', () => {
      it('does not render the LDAP override dropdown item', async () => {
        await createComponent({
          permissions: { canOverride: true },
          member: {
            ...member,
            isOverridden: true,
          },
        });

        expect(findLdapOverrideDropdownItem().exists()).toBe(false);
      });
    });
  });

  describe('when member does not have `canOverride` permissions', () => {
    it('does not render the LDAP override dropdown item', async () => {
      await createComponent({
        permissions: { canOverride: false },
      });

      expect(findLdapOverrideDropdownItem().exists()).toBe(false);
    });
  });
});
