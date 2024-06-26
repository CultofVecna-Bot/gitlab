<script>
import { GlAvatar, GlLoadingIcon } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';

export default {
  components: {
    GlAvatar,
    GlLoadingIcon,
  },

  directives: {
    SafeHtml,
  },

  props: {
    char: {
      type: String,
      required: true,
    },

    nodeType: {
      type: String,
      required: true,
    },

    nodeProps: {
      type: Object,
      required: true,
    },

    items: {
      type: Array,
      required: true,
    },

    command: {
      type: Function,
      required: true,
    },

    loading: {
      type: Boolean,
      required: false,
      default: false,
    },

    query: {
      type: String,
      required: false,
      default: '',
    },
  },

  data() {
    return {
      selectedIndex: -1,
    };
  },

  computed: {
    isReference() {
      return this.nodeType.startsWith('reference');
    },

    isCommand() {
      return this.isReference && this.nodeProps.referenceType === 'command';
    },

    isUser() {
      return this.isReference && this.nodeProps.referenceType === 'user';
    },

    isIssue() {
      return this.isReference && this.nodeProps.referenceType === 'issue';
    },

    isLabel() {
      return this.isReference && this.nodeProps.referenceType === 'label';
    },

    isEpic() {
      return this.isReference && this.nodeProps.referenceType === 'epic';
    },

    isSnippet() {
      return this.isReference && this.nodeProps.referenceType === 'snippet';
    },

    isVulnerability() {
      return this.isReference && this.nodeProps.referenceType === 'vulnerability';
    },

    isMergeRequest() {
      return this.isReference && this.nodeProps.referenceType === 'merge_request';
    },

    isMilestone() {
      return this.isReference && this.nodeProps.referenceType === 'milestone';
    },

    isEmoji() {
      return this.nodeType === 'emoji';
    },

    shouldSelectFirstItem() {
      return this.items.length && this.query;
    },
  },

  watch: {
    items() {
      this.selectedIndex = this.shouldSelectFirstItem ? 0 : -1;
    },
    selectedIndex() {
      this.scrollIntoView();
    },
  },

  mounted() {
    if (this.shouldSelectFirstItem) {
      this.selectedIndex = 0;
    }
  },

  methods: {
    getText(item) {
      if (this.isEmoji) return item.emoji.e;

      switch (this.isReference && this.nodeProps.referenceType) {
        case 'user':
          return `${this.char}${item.username}`;
        case 'issue':
        case 'merge_request':
          return `${this.char}${item.iid}`;
        case 'snippet':
          return `${this.char}${item.id}`;
        case 'milestone':
          return `${this.char}${item.title}`;
        case 'label':
          return item.title;
        case 'command':
          return `${this.char}${item.name}`;
        case 'epic':
          return item.reference;
        case 'vulnerability':
          return `[vulnerability:${item.id}]`;
        default:
          return '';
      }
    },

    getProps(item) {
      const props = {};

      if (this.isEmoji) {
        Object.assign(props, {
          name: item.emoji.name,
          unicodeVersion: item.emoji.u,
          title: item.emoji.d,
          moji: item.emoji.e,
        });
      }

      if (this.isLabel || this.isMilestone) {
        Object.assign(props, {
          originalText: `${this.char}${
            /\W/.test(item.title) ? JSON.stringify(item.title) : item.title
          }`,
        });
      }

      if (this.isLabel) {
        Object.assign(props, {
          text: item.title,
          color: item.color,
        });
      }

      Object.assign(props, this.nodeProps);

      return props;
    },

    onKeyDown({ event }) {
      if (!this.items.length) return false;

      if (event.key === 'ArrowUp') {
        this.upHandler();
        return true;
      }

      if (event.key === 'ArrowDown') {
        this.downHandler();
        return true;
      }

      if (event.key === 'Enter' || event.key === 'Tab') {
        this.enterHandler();
        return true;
      }

      return false;
    },

    upHandler() {
      this.selectedIndex = (this.selectedIndex + this.items.length - 1) % this.items.length;
    },

    downHandler() {
      this.selectedIndex = (this.selectedIndex + 1) % this.items.length;
    },

    enterHandler() {
      this.selectItem(this.selectedIndex);
    },

    scrollIntoView() {
      this.$refs.dropdownItems?.[this.selectedIndex]?.scrollIntoView({ block: 'nearest' });
    },

    selectItem(index) {
      const item = this.items[index];

      if (item) {
        this.command({
          text: this.getText(item),
          ...this.getProps(item),
        });
      }
    },

    avatarSubLabel(item) {
      return item.count ? `${item.name} (${item.count})` : item.name;
    },

    highlight(text) {
      return this.query
        ? String(text).replace(
            new RegExp(this.query, 'i'),
            (match) => `<strong class="gl-text-body!">${match}</strong>`,
          )
        : text;
    },
  },
  safeHtmlConfig: { ALLOWED_TAGS: ['strong'] },
};
</script>

<template>
  <div class="gl-new-dropdown content-editor-suggestions-dropdown">
    <div
      v-if="!loading && items.length > 0"
      class="gl-new-dropdown-panel gl-display-block! gl-absolute"
    >
      <div class="gl-new-dropdown-inner">
        <ul class="gl-new-dropdown-contents" data-testid="content-editor-suggestions-dropdown">
          <li
            v-for="(item, index) in items"
            :key="index"
            role="presentation"
            class="gl-new-dropdown-item"
            :class="{ focused: index === selectedIndex }"
          >
            <div
              ref="dropdownItems"
              type="button"
              role="menuitem"
              class="gl-new-dropdown-item-content"
              @click="selectItem(index)"
            >
              <div class="gl-new-dropdown-item-text-wrapper">
                <span v-if="isUser" class="gl-flex">
                  <gl-avatar
                    :src="item.avatar_url"
                    :entity-name="item.username"
                    :size="24"
                    :shape="item.type === 'Group' ? 'rect' : 'circle'"
                    class="gl-vertical-align-middle gl-mx-2"
                  />
                  <span class="gl-vertical-align-middle">
                    <span v-safe-html:safeHtmlConfig="highlight(item.username)"></span>
                    <small
                      v-safe-html:safeHtmlConfig="highlight(avatarSubLabel(item))"
                      class="gl-text-gray-500"
                    ></small>
                  </span>
                </span>
                <span v-if="isIssue || isMergeRequest">
                  <small
                    v-safe-html:safeHtmlConfig="highlight(item.iid)"
                    class="gl-text-gray-500"
                  ></small>
                  <span v-safe-html:safeHtmlConfig="highlight(item.title)"></span>
                </span>
                <span v-if="isVulnerability || isSnippet">
                  <small
                    v-safe-html:safeHtmlConfig="highlight(item.id)"
                    class="gl-text-gray-500"
                  ></small>
                  <span v-safe-html:safeHtmlConfig="highlight(item.title)"></span>
                </span>
                <span v-if="isEpic">
                  <small
                    v-safe-html:safeHtmlConfig="highlight(item.reference)"
                    class="gl-text-gray-500"
                  ></small>
                  <span v-safe-html:safeHtmlConfig="highlight(item.title)"></span>
                </span>
                <span v-if="isMilestone">
                  <span v-safe-html:safeHtmlConfig="highlight(item.title)"></span>
                </span>
                <span v-if="isLabel" class="gl-display-flex">
                  <span
                    data-testid="label-color-box"
                    class="dropdown-label-box gl-flex-shrink-0 gl-top-0 gl-mr-3"
                    :style="{ backgroundColor: item.color }"
                  ></span>
                  <span v-safe-html:safeHtmlConfig="highlight(item.title)"></span>
                </span>
                <div v-if="isCommand">
                  <div class="gl-mb-1">
                    /<span v-safe-html:safeHtmlConfig="highlight(item.name)"></span>
                    <span class="gl-text-gray-500 gl-font-sm">{{ item.params[0] }}</span>
                  </div>
                  <em
                    v-safe-html:safeHtmlConfig="highlight(item.description)"
                    class="gl-text-gray-500 gl-font-sm"
                  ></em>
                </div>
                <div v-if="isEmoji" class="gl-display-flex gl-align-items-center">
                  <div class="gl-pr-4 gl-font-lg">
                    <gl-emoji
                      :key="item.emoji.e"
                      :data-name="item.emoji.name"
                      :title="item.emoji.d"
                      :data-unicode-version="item.emoji.u"
                      :data-fallback-src="item.emoji.src"
                      >{{ item.emoji.e }}</gl-emoji
                    >
                  </div>
                  <div class="gl-flex-grow-1">
                    <span v-safe-html:safeHtmlConfig="highlight(item.fieldValue)"></span>
                  </div>
                </div>
              </div>
            </div>
          </li>
        </ul>
      </div>
    </div>
    <div v-if="loading" class="gl-new-dropdown-panel gl-display-block! gl-absolute">
      <div class="gl-new-dropdown-inner">
        <div class="gl-px-4 gl-py-3">
          <gl-loading-icon size="sm" class="gl-display-inline-block" /> {{ __('Loading...') }}
        </div>
      </div>
    </div>
  </div>
</template>
