import Vue from 'vue';
import Translate from '~/vue_shared/translate';
import { createStore } from './stores';
import PackagesListApp from './components/packages_list_app.vue';

Vue.use(Translate);

export default () => {
  const el = document.getElementById('js-vue-packages-list');
  const store = createStore();
  store.dispatch('setInitialState', el.dataset);

  return new Vue({
    el,
    store,
    components: {
      PackagesListApp,
    },
    render(createElement) {
      return createElement('packages-list-app');
    },
  });
};
