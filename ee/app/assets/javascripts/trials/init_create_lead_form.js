import Vue from 'vue';
import TrialCreateLeadForm from 'ee/trials/components/trial_create_lead_form.vue';
import apolloProvider from 'ee/subscriptions/buy_addons_shared/graphql';

export const initTrialCreateLeadForm = () => {
  const el = document.querySelector('#js-trial-create-lead-form');

  const {
    submitPath,
    firstName,
    lastName,
    companyName,
    companySize,
    country,
    phoneNumber,
  } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      user: {
        firstName,
        lastName,
        companyName,
        companySize: companySize || null,
        country: country || null,
        phoneNumber,
      },
      submitPath,
    },
    render(createElement) {
      return createElement(TrialCreateLeadForm);
    },
  });
};
