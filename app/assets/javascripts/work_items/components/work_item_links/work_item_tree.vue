<script>
import { GlToggle } from '@gitlab/ui';
import {
  FORM_TYPES,
  WIDGET_TYPE_HIERARCHY,
  WORK_ITEMS_TREE_TEXT_MAP,
  WORK_ITEM_TYPE_ENUM_OBJECTIVE,
  WORK_ITEM_TYPE_ENUM_KEY_RESULT,
  I18N_WORK_ITEM_SHOW_LABELS,
} from '../../constants';
import WidgetWrapper from '../widget_wrapper.vue';
import OkrActionsSplitButton from './okr_actions_split_button.vue';
import WorkItemLinksForm from './work_item_links_form.vue';
import WorkItemChildrenWrapper from './work_item_children_wrapper.vue';

export default {
  FORM_TYPES,
  WORK_ITEMS_TREE_TEXT_MAP,
  WORK_ITEM_TYPE_ENUM_OBJECTIVE,
  WORK_ITEM_TYPE_ENUM_KEY_RESULT,
  components: {
    OkrActionsSplitButton,
    WidgetWrapper,
    WorkItemLinksForm,
    WorkItemChildrenWrapper,
    GlToggle,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
    parentWorkItemType: {
      type: String,
      required: false,
      default: '',
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: false,
      default: null,
    },
    confidential: {
      type: Boolean,
      required: false,
      default: false,
    },
    children: {
      type: Array,
      required: false,
      default: () => [],
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      error: undefined,
      isShownAddForm: false,
      formType: null,
      childType: null,
      widgetName: 'tasks',
      showLabels: true,
    };
  },
  computed: {
    childrenIds() {
      return this.children.map((c) => c.id);
    },
    hasIndirectChildren() {
      return this.children
        .map(
          (child) => child.widgets?.find((widget) => widget.type === WIDGET_TYPE_HIERARCHY) || {},
        )
        .some((hierarchy) => hierarchy.hasChildren);
    },
  },
  methods: {
    showAddForm(formType, childType) {
      this.$refs.wrapper.show();
      this.isShownAddForm = true;
      this.formType = formType;
      this.childType = childType;
      this.$nextTick(() => {
        this.$refs.wiLinksForm.$refs.wiTitleInput?.$el.focus();
      });
    },
    hideAddForm() {
      this.isShownAddForm = false;
    },
    showModal({ event, child }) {
      this.$emit('show-modal', { event, modalWorkItem: child });
    },
  },
  i18n: {
    showLabelsLabel: I18N_WORK_ITEM_SHOW_LABELS,
  },
};
</script>

<template>
  <widget-wrapper
    ref="wrapper"
    :widget-name="widgetName"
    :error="error"
    data-testid="work-item-tree"
    @dismissAlert="error = undefined"
  >
    <template #header>
      {{ $options.WORK_ITEMS_TREE_TEXT_MAP[workItemType].title }}
    </template>
    <template #header-right>
      <gl-toggle
        class="gl-mr-4"
        :value="showLabels"
        :label="$options.i18n.showLabelsLabel"
        label-position="left"
        label-id="relationship-toggle-labels"
        @change="showLabels = $event"
      />
      <okr-actions-split-button
        v-if="canUpdate"
        @showCreateObjectiveForm="
          showAddForm($options.FORM_TYPES.create, $options.WORK_ITEM_TYPE_ENUM_OBJECTIVE)
        "
        @showAddObjectiveForm="
          showAddForm($options.FORM_TYPES.add, $options.WORK_ITEM_TYPE_ENUM_OBJECTIVE)
        "
        @showCreateKeyResultForm="
          showAddForm($options.FORM_TYPES.create, $options.WORK_ITEM_TYPE_ENUM_KEY_RESULT)
        "
        @showAddKeyResultForm="
          showAddForm($options.FORM_TYPES.add, $options.WORK_ITEM_TYPE_ENUM_KEY_RESULT)
        "
      />
    </template>
    <template #body>
      <div class="gl-new-card-content">
        <div v-if="!isShownAddForm && children.length === 0" data-testid="tree-empty">
          <p class="gl-new-card-empty">
            {{ $options.WORK_ITEMS_TREE_TEXT_MAP[workItemType].empty }}
          </p>
        </div>
        <work-item-links-form
          v-if="isShownAddForm"
          ref="wiLinksForm"
          data-testid="add-tree-form"
          :full-path="fullPath"
          :issuable-gid="workItemId"
          :work-item-iid="workItemIid"
          :form-type="formType"
          :parent-work-item-type="parentWorkItemType"
          :children-type="childType"
          :children-ids="childrenIds"
          :parent-confidential="confidential"
          @cancel="hideAddForm"
          @addChild="$emit('addChild')"
        />
        <work-item-children-wrapper
          :children="children"
          :can-update="canUpdate"
          :full-path="fullPath"
          :work-item-id="workItemId"
          :work-item-iid="workItemIid"
          :work-item-type="workItemType"
          :show-labels="showLabels"
          @error="error = $event"
          @show-modal="showModal"
        />
      </div>
    </template>
  </widget-wrapper>
</template>
