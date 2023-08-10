import {
  ADD_ON_CODE_SUGGESTIONS,
  HEADER_TOTAL_ENTRIES,
  HEADER_PAGE_NUMBER,
  HEADER_ITEMS_PER_PAGE,
} from 'ee/usage_quotas/seats/constants';

export const mockDataSeats = {
  data: [
    {
      id: 2,
      name: 'Administrator',
      username: 'root',
      avatar_url: 'path/to/img_administrator',
      web_url: 'path/to/administrator',
      email: 'administrator@email.com',
      last_activity_on: '2020-03-01',
      last_login_at: '2022-11-10T10:58:05.492Z',
      membership_type: 'group_member',
      membership_state: 'active',
      removable: true,
      is_last_owner: true,
    },
    {
      id: 3,
      name: 'Agustin Walker',
      username: 'lester.orn',
      avatar_url: 'path/to/img_agustin_walker',
      web_url: 'path/to/agustin_walker',
      email: 'agustin_walker@email.com',
      last_activity_on: '2020-03-01',
      last_login_at: '2021-01-20T10:58:05.492Z',
      membership_type: 'project_member',
      membership_state: 'active',
      removable: true,
      is_last_owner: false,
    },
    {
      id: 4,
      name: 'Joella Miller',
      username: 'era',
      avatar_url: 'path/to/img_joella_miller',
      web_url: 'path/to/joella_miller',
      last_activity_on: null,
      last_login_at: null,
      email: null,
      membership_type: 'group_invite',
      membership_state: 'active',
      removable: false,
      is_last_owner: false,
    },
    {
      id: 5,
      name: 'John Doe',
      username: 'jdoe',
      avatar_url: 'path/to/img_john_doe',
      web_url: 'path/to/john_doe',
      last_activity_on: null,
      last_login_at: null,
      email: 'jdoe@email.com',
      membership_type: 'project_invite',
      membership_state: 'awaiting',
      removable: false,
      is_last_owner: false,
    },
    {
      id: 6,
      avatar_url: 'path/to/img_john_snow',
      name: 'John Snow',
      username: 'jown.snow',
      email: 'jsnow@email.com',
      web_url: 'path/to/john_snow',
      last_activity_on: '2020-03-01',
      last_login_at: null,
      membership_type: 'group_member',
      membership_state: 'awaiting',
      removable: true,
      is_last_owner: false,
    },
    {
      id: 7,
      avatar_url: 'path/to/img_curent_user',
      name: 'Current user',
      username: 'current.user',
      email: 'current_user@email.com',
      web_url: 'path/to/current_user',
      last_activity_on: '2020-03-01',
      last_login_at: null,
      membership_type: 'group_member',
      membership_state: 'active',
      removable: true,
      is_last_owner: false,
    },
  ],
  headers: {
    [HEADER_TOTAL_ENTRIES]: '3',
    [HEADER_PAGE_NUMBER]: '1',
    [HEADER_ITEMS_PER_PAGE]: '1',
  },
};

export const mockMemberDetails = [
  {
    id: 173,
    source_id: 155,
    source_full_name: 'group_with_ultimate_plan / subgroup',
    created_at: '2021-02-25T08:21:32.257Z',
    expires_at: null,
    access_level: { string_value: 'Owner', integer_value: 50 },
  },
];

export const mockTableItems = [
  {
    email: 'administrator@email.com',
    user: {
      id: 2,
      avatar_url: 'path/to/img_administrator',
      name: 'Administrator',
      username: '@root',
      web_url: 'path/to/administrator',
      last_activity_on: '2020-03-01',
      last_login_at: '2022-11-10T10:58:05.492Z',
      membership_type: 'group_member',
      membership_state: 'active',
      removable: true,
      is_last_owner: true,
    },
  },
  {
    email: 'agustin_walker@email.com',
    user: {
      id: 3,
      avatar_url: 'path/to/img_agustin_walker',
      name: 'Agustin Walker',
      username: '@lester.orn',
      web_url: 'path/to/agustin_walker',
      last_activity_on: '2020-03-01',
      last_login_at: '2021-01-20T10:58:05.492Z',
      membership_type: 'project_member',
      membership_state: 'active',
      removable: true,
      is_last_owner: false,
    },
  },
  {
    email: null,
    user: {
      id: 4,
      avatar_url: 'path/to/img_joella_miller',
      name: 'Joella Miller',
      username: '@era',
      web_url: 'path/to/joella_miller',
      last_activity_on: null,
      last_login_at: null,
      membership_type: 'group_invite',
      membership_state: 'active',
      removable: false,
      is_last_owner: false,
    },
  },
  {
    email: 'jdoe@email.com',
    user: {
      id: 5,
      avatar_url: 'path/to/img_john_doe',
      name: 'John Doe',
      username: '@jdoe',
      web_url: 'path/to/john_doe',
      last_activity_on: null,
      last_login_at: null,
      membership_type: 'project_invite',
      membership_state: 'awaiting',
      removable: false,
      is_last_owner: false,
    },
  },
  {
    email: 'jsnow@email.com',
    user: {
      id: 6,
      avatar_url: 'path/to/img_john_snow',
      name: 'John Snow',
      username: '@jown.snow',
      web_url: 'path/to/john_snow',
      last_activity_on: '2020-03-01',
      last_login_at: null,
      membership_type: 'group_member',
      membership_state: 'awaiting',
      removable: true,
      is_last_owner: false,
    },
  },
  {
    email: 'current_user@email.com',
    user: {
      id: 7,
      avatar_url: 'path/to/img_curent_user',
      name: 'Current user',
      username: '@current.user',
      web_url: 'path/to/current_user',
      last_activity_on: '2020-03-01',
      last_login_at: null,
      membership_type: 'group_member',
      membership_state: 'active',
      removable: true,
      is_last_owner: false,
    },
  },
];

export const mockTableItemsWithCodeSuggestionsAddOn = [
  {
    email: 'administrator@email.com',
    user: {
      add_ons: {
        applicable: [{ name: ADD_ON_CODE_SUGGESTIONS }],
        assigned: [{ name: ADD_ON_CODE_SUGGESTIONS }],
      },
      id: 2,
      avatar_url: 'path/to/img_administrator',
      name: 'Administrator',
      username: '@root',
      web_url: 'path/to/administrator',
      last_activity_on: '2020-03-01',
      last_login_at: '2022-11-10T10:58:05.492Z',
      membership_type: 'group_member',
      membership_state: 'active',
      removable: true,
      is_last_owner: true,
    },
  },
  {
    email: 'agustin_walker@email.com',
    user: {
      add_ons: {
        applicable: [{ name: ADD_ON_CODE_SUGGESTIONS }],
        assigned: [],
      },
      id: 3,
      avatar_url: 'path/to/img_agustin_walker',
      name: 'Agustin Walker',
      username: '@lester.orn',
      web_url: 'path/to/agustin_walker',
      last_activity_on: '2020-03-01',
      last_login_at: '2021-01-20T10:58:05.492Z',
      membership_type: 'project_member',
      membership_state: 'active',

      removable: true,
      is_last_owner: false,
    },
  },
  {
    email: null,
    user: {
      add_ons: {
        applicable: [],
        assigned: [],
      },
      id: 4,
      avatar_url: 'path/to/img_joella_miller',
      name: 'Joella Miller',
      username: '@era',
      web_url: 'path/to/joella_miller',
      last_activity_on: null,
      last_login_at: null,
      membership_type: 'group_invite',
      membership_state: 'active',
      removable: false,
      is_last_owner: false,
    },
  },
];

export const mockUserSubscription = {
  plan: {
    code: null,
    name: null,
    trial: false,
    auto_renew: null,
    upgradable: false,
  },
  usage: {
    seats_in_subscription: 10,
    seats_in_use: 5,
    max_seats_used: 2,
    seats_owed: 3,
  },
  billing: {
    subscription_start_date: '2022-03-08',
    subscription_end_date: null,
    trial_ends_on: null,
  },
};

export const assignedAddonData = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/13',
      addOnPurchase: {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: ADD_ON_CODE_SUGGESTIONS,
        assignedQuantity: 5,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
      __typename: 'Namespace',
    },
  },
};

export const noAssignedAddonData = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/13',
      addOnPurchase: {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: ADD_ON_CODE_SUGGESTIONS,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
      __typename: 'Namespace',
    },
  },
};

export const noPurchasedAddonData = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/13',
      addOnPurchase: null,
    },
  },
};
