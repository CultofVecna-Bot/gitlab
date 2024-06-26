import setHighlightClass from 'ee_else_ce/search/highlight_blob_search_result';
import { queryToObject } from '~/lib/utils/url_utility';
import syntaxHighlight from '~/syntax_highlight';
import { initSidebar } from './sidebar';
import { initSearchSort } from './sort';
import createStore from './store';
import { initTopbar } from './topbar';
import { initBlobRefSwitcher } from './under_topbar';

const sidebarInitState = () => {
  const el = document.getElementById('js-search-sidebar');
  if (!el) return {};

  const { navigationJson, searchType, groupInitialJson, projectInitialJson } = el.dataset;

  const navigationJsonParsed = JSON.parse(navigationJson);
  const groupInitialJsonParsed = JSON.parse(groupInitialJson);
  const projectInitialJsonParsed = JSON.parse(projectInitialJson);

  return { navigationJsonParsed, searchType, groupInitialJsonParsed, projectInitialJsonParsed };
};

export const initSearchApp = () => {
  syntaxHighlight(document.querySelectorAll('.js-search-results'));
  const query = queryToObject(window.location.search, { gatherArrays: true });
  const {
    navigationJsonParsed: navigation,
    searchType,
    groupInitialJsonParsed: groupInitialJson,
    projectInitialJsonParsed: projectInitialJson,
  } = sidebarInitState() || {};

  const store = createStore({
    query,
    navigation,
    searchType,
    groupInitialJson,
    projectInitialJson,
  });

  initTopbar(store);
  initSidebar(store);
  initSearchSort(store);

  setHighlightClass(query.search); // Code Highlighting
  initBlobRefSwitcher(); // Code Search Branch Picker
};
