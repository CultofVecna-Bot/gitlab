import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import SecurityPoliciesListApp from './components/policies/app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export default (el, namespaceType) => {
  if (!el) return null;

  const {
    assignedPolicyProject,
    disableSecurityPolicyProject,
    disableScanPolicyUpdate,
    emptyFilterSvgPath,
    emptyListSvgPath,
    documentationPath,
    newPolicyPath,
    namespacePath,
  } = el.dataset;

  return new Vue({
    apolloProvider,
    el,
    name: 'PoliciesAppRoot',
    provide: {
      assignedPolicyProject: JSON.parse(assignedPolicyProject),
      disableSecurityPolicyProject: parseBoolean(disableSecurityPolicyProject),
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      documentationPath,
      newPolicyPath,
      emptyFilterSvgPath,
      emptyListSvgPath,
      namespacePath,
      namespaceType,
    },
    render(createElement) {
      return createElement(SecurityPoliciesListApp);
    },
  });
};
