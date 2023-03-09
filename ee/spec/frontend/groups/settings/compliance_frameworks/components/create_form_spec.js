import * as Sentry from '@sentry/browser';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';

import CreateForm from 'ee/groups/settings/compliance_frameworks/components/create_form.vue';
import FormStatus from 'ee/groups/settings/compliance_frameworks/components/form_status.vue';
import SharedForm from 'ee/groups/settings/compliance_frameworks/components/shared_form.vue';
import { SAVE_ERROR } from 'ee/groups/settings/compliance_frameworks/constants';
import createComplianceFrameworkMutation from 'ee/groups/settings/compliance_frameworks/graphql/queries/create_compliance_framework.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { visitUrl } from '~/lib/utils/url_utility';

import { validCreateResponse, errorCreateResponse } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility');

describe('CreateForm', () => {
  let wrapper;

  const propsData = {
    groupPath: 'group-1',
    groupEditPath: 'group-1/edit',
    pipelineConfigurationFullPathEnabled: true,
  };

  const sentryError = new Error('Network error');
  const sentrySaveError = new Error('Invalid values given');

  const create = jest.fn().mockResolvedValue(validCreateResponse);
  const createWithNetworkErrors = jest.fn().mockRejectedValue(sentryError);
  const createWithErrors = jest.fn().mockResolvedValue(errorCreateResponse);

  const findForm = () => wrapper.findComponent(SharedForm);
  const findFormStatus = () => wrapper.findComponent(FormStatus);

  function createMockApolloProvider(requestHandlers) {
    Vue.use(VueApollo);

    return createMockApollo(requestHandlers);
  }

  function createComponent(requestHandlers = []) {
    return shallowMount(CreateForm, {
      apolloProvider: createMockApolloProvider(requestHandlers),
      propsData,
    });
  }

  async function submitForm(name, description, pipelineConfiguration, color) {
    await waitForPromises();

    findForm().vm.$emit('update:name', name);
    findForm().vm.$emit('update:description', description);
    findForm().vm.$emit('update:pipelineConfigurationFullPath', pipelineConfiguration);
    findForm().vm.$emit('update:color', color);
    findForm().vm.$emit('submit');

    await waitForPromises();
  }

  describe('initialized', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('sets the submit button text on the form', () => {
      expect(findForm().props('submitButtonText')).toBe('Add framework');
    });
  });

  describe('loading', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('passes the loading state to the form status', () => {
      expect(findFormStatus().props('loading')).toBe(false);
    });
  });

  describe('onSubmit', () => {
    const name = 'Test';
    const description = 'Test description';
    const pipelineConfigurationFullPath = 'file.yml@group/project';
    const color = '#000000';
    const creationProps = {
      input: {
        namespacePath: 'group-1',
        params: {
          name,
          description,
          pipelineConfigurationFullPath,
          color,
        },
      },
    };

    it('passes the error to the form status when saving causes an exception and does not redirect', async () => {
      const captureExceptionSpy = jest.spyOn(Sentry, 'captureException');
      wrapper = createComponent([[createComplianceFrameworkMutation, createWithNetworkErrors]]);

      await submitForm(name, description, pipelineConfigurationFullPath, color);

      expect(createWithNetworkErrors).toHaveBeenCalledWith(creationProps);
      expect(findFormStatus().props('loading')).toBe(false);
      expect(visitUrl).not.toHaveBeenCalled();
      expect(findFormStatus().props('error')).toBe(SAVE_ERROR);
      expect(captureExceptionSpy.mock.calls[0][0].networkError).toStrictEqual(sentryError);
    });

    it('passes the errors to the form status when saving fails and does not redirect', async () => {
      const captureExceptionSpy = jest.spyOn(Sentry, 'captureException');
      wrapper = createComponent([[createComplianceFrameworkMutation, createWithErrors]]);

      await submitForm(name, description, pipelineConfigurationFullPath, color);

      expect(createWithErrors).toHaveBeenCalledWith(creationProps);
      expect(findFormStatus().props('loading')).toBe(false);
      expect(visitUrl).not.toHaveBeenCalled();
      expect(findFormStatus().props('error')).toBe('Invalid values given');
      expect(captureExceptionSpy).toHaveBeenCalledWith(sentrySaveError);
    });

    it('saves inputted values, redirects and continues to show loading while redirecting', async () => {
      wrapper = createComponent([[createComplianceFrameworkMutation, create]]);

      await submitForm(name, description, pipelineConfigurationFullPath, color);

      expect(create).toHaveBeenCalledWith(creationProps);
      expect(findFormStatus().props('loading')).toBe(true);
      expect(visitUrl).toHaveBeenCalledWith(propsData.groupEditPath);
    });
  });
});
