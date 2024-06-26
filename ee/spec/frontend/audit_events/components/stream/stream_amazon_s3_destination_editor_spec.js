import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlForm } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import amazonS3ConfigurationCreate from 'ee/audit_events/graphql/mutations/create_amazon_s3_destination.mutation.graphql';
import amazonS3ConfigurationUpdate from 'ee/audit_events/graphql/mutations/update_amazon_s3_destination.mutation.graphql';
import StreamAmazonS3DestinationEditor from 'ee/audit_events/components/stream/stream_amazon_s3_destination_editor.vue';
import StreamDeleteModal from 'ee/audit_events/components/stream/stream_delete_modal.vue';
import { AUDIT_STREAMS_NETWORK_ERRORS, ADD_STREAM_EDITOR_I18N } from 'ee/audit_events/constants';
import {
  amazonS3DestinationCreateMutationPopulator,
  amazonS3DestinationUpdateMutationPopulator,
  groupPath,
  mockAmazonS3Destinations,
} from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('StreamDestinationEditor', () => {
  let wrapper;

  const createComponent = ({
    mountFn = mountExtended,
    props = {},
    apolloHandlers = [
      [
        amazonS3ConfigurationCreate,
        jest.fn().mockResolvedValue(amazonS3DestinationCreateMutationPopulator()),
      ],
    ],
  } = {}) => {
    const mockApollo = createMockApollo(apolloHandlers);
    wrapper = mountFn(StreamAmazonS3DestinationEditor, {
      attachTo: document.body,
      provide: {
        groupPath,
      },
      propsData: {
        ...props,
      },
      apolloProvider: mockApollo,
    });
  };

  const findWarningMessage = () => wrapper.findByTestId('data-warning');
  const findAlertErrors = () => wrapper.findAllByTestId('alert-errors');
  const findDestinationForm = () => wrapper.findComponent(GlForm);
  const findAddStreamBtn = () => wrapper.findByTestId('stream-destination-add-button');
  const findCancelStreamBtn = () => wrapper.findByTestId('stream-destination-cancel-button');
  const findDeleteBtn = () => wrapper.findByTestId('stream-destination-delete-button');
  const findDeleteModal = () => wrapper.findComponent(StreamDeleteModal);

  const findNameFormGroup = () => wrapper.findByTestId('name-form-group');
  const findName = () => wrapper.findByTestId('name');
  const findAccessKeyXidFormGroup = () => wrapper.findByTestId('access-key-xid-form-group');
  const findAccessKeyXid = () => wrapper.findByTestId('access-key-xid');
  const findAwsRegionFormGroup = () => wrapper.findByTestId('aws-region-form-group');
  const findAwsRegion = () => wrapper.findByTestId('aws-region');
  const findBucketNameFormGroup = () => wrapper.findByTestId('bucket-name-form-group');
  const findBucketName = () => wrapper.findByTestId('bucket-name');
  const findSecretAccessKeyFormGroup = () => wrapper.findByTestId('secret-access-key-form-group');
  const findSecretAccessKey = () => wrapper.findByTestId('secret-access-key');
  const findSecretAccessKeyAddButton = () => wrapper.findByTestId('secret-access-key-add-button');
  const findSecretAccessKeyCancelButton = () =>
    wrapper.findByTestId('secret-access-key-cancel-button');

  afterEach(() => {
    createAlert.mockClear();
  });

  describe('Group amazon S3 StreamDestinationEditor', () => {
    describe('when initialized', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should render the destinations warning', () => {
        expect(findWarningMessage().props('title')).toBe(ADD_STREAM_EDITOR_I18N.WARNING_TITLE);
      });

      it('should render the destination name input', () => {
        expect(findNameFormGroup().exists()).toBe(true);
        expect(findName().exists()).toBe(true);
        expect(findName().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_NAME_PLACEHOLDER,
        );
      });

      it('should render the destination AccessKeyXid input', () => {
        expect(findAccessKeyXidFormGroup().exists()).toBe(true);
        expect(findAccessKeyXid().exists()).toBe(true);
        expect(findAccessKeyXid().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_ACCESS_KEY_XID_PLACEHOLDER,
        );
      });

      it('should render the destination awsRegion input', () => {
        expect(findAwsRegionFormGroup().exists()).toBe(true);
        expect(findAwsRegion().exists()).toBe(true);
        expect(findAwsRegion().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_AWS_REGION_PLACEHOLDER,
        );
      });

      it('should render the destination BucketName input', () => {
        expect(findBucketNameFormGroup().exists()).toBe(true);
        expect(findBucketName().exists()).toBe(true);
        expect(findBucketName().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_BUCKET_NAME_PLACEHOLDER,
        );
      });

      it('should not render the destination Secret Access Key input', () => {
        expect(findSecretAccessKeyFormGroup().exists()).toBe(true);
        expect(findSecretAccessKey().exists()).toBe(true);
      });

      it('does not render the delete button', () => {
        expect(findDeleteBtn().exists()).toBe(false);
      });

      it('renders the add button text', () => {
        expect(findAddStreamBtn().attributes('name')).toBe(ADD_STREAM_EDITOR_I18N.ADD_BUTTON_NAME);
        expect(findAddStreamBtn().text()).toBe(ADD_STREAM_EDITOR_I18N.ADD_BUTTON_TEXT);
      });

      it('disables the add button at first', () => {
        expect(findAddStreamBtn().props('disabled')).toBe(true);
      });
    });

    describe('add destination event', () => {
      it('should emit add event after destination added', async () => {
        createComponent();

        await findName().setValue(mockAmazonS3Destinations[0].name);
        await findAccessKeyXid().setValue(mockAmazonS3Destinations[0].accessKeyXid);
        await findAwsRegion().setValue(mockAmazonS3Destinations[0].awsRegion);
        await findBucketName().setValue(mockAmazonS3Destinations[0].bucketName);
        await findSecretAccessKey().setValue(mockAmazonS3Destinations[0].secretAccessKey);

        expect(findAddStreamBtn().props('disabled')).toBe(false);

        await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(0);
        expect(wrapper.emitted('error')).toBeUndefined();
        expect(wrapper.emitted('added')).toBeDefined();
      });

      it('should not emit add destination event and reports error when server returns error', async () => {
        const errorMsg = 'Destination hosts limit exceeded';
        createComponent({
          apolloHandlers: [
            [
              amazonS3ConfigurationCreate,
              jest.fn().mockResolvedValue(amazonS3DestinationCreateMutationPopulator([errorMsg])),
            ],
          ],
        });

        findName().setValue(mockAmazonS3Destinations[0].name);
        findAccessKeyXid().setValue(mockAmazonS3Destinations[0].accessKeyXid);
        findAwsRegion().setValue(mockAmazonS3Destinations[0].awsRegion);
        findBucketName().setValue(mockAmazonS3Destinations[0].bucketName);
        findSecretAccessKey().setValue(mockAmazonS3Destinations[0].secretAccessKey);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(errorMsg);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('added')).toBeUndefined();
      });

      it('should not emit add destination event and reports error when network error occurs', async () => {
        const sentryError = new Error('Network error');
        const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        createComponent({
          apolloHandlers: [[amazonS3ConfigurationCreate, jest.fn().mockRejectedValue(sentryError)]],
        });

        findName().setValue(mockAmazonS3Destinations[0].name);
        findAccessKeyXid().setValue(mockAmazonS3Destinations[0].accessKeyXid);
        findAwsRegion().setValue(mockAmazonS3Destinations[0].awsRegion);
        findBucketName().setValue(mockAmazonS3Destinations[0].bucketName);
        findSecretAccessKey().setValue(mockAmazonS3Destinations[0].secretAccessKey);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.CREATING_ERROR);
        expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('added')).toBeUndefined();
      });
    });

    describe('cancel event', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should emit cancel event correctly', () => {
        findCancelStreamBtn().vm.$emit('click');

        expect(wrapper.emitted('cancel')).toBeDefined();
      });
    });

    describe('when editing an existing destination', () => {
      describe('renders', () => {
        beforeEach(() => {
          createComponent({ props: { item: mockAmazonS3Destinations[0] } });
        });

        it('the destination fields', () => {
          expect(findName().exists()).toBe(true);
          expect(findName().element.value).toBe(mockAmazonS3Destinations[0].name);
          expect(findAccessKeyXid().exists()).toBe(true);
          expect(findAccessKeyXid().element.value).toBe(mockAmazonS3Destinations[0].accessKeyXid);
          expect(findAwsRegion().exists()).toBe(true);
          expect(findAwsRegion().element.value).toBe(mockAmazonS3Destinations[0].awsRegion);
          expect(findBucketName().exists()).toBe(true);
          expect(findBucketName().element.value).toBe(mockAmazonS3Destinations[0].bucketName);
          expect(findSecretAccessKey().exists()).toBe(false);
          expect(findSecretAccessKeyAddButton().exists()).toBe(true);
          expect(findSecretAccessKeyCancelButton().exists()).toBe(false);
        });

        it('the delete button', () => {
          expect(findDeleteBtn().exists()).toBe(true);
        });

        it('renders the save button text', () => {
          expect(findAddStreamBtn().attributes('name')).toBe(
            ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_NAME,
          );
          expect(findAddStreamBtn().text()).toBe(ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_TEXT);
        });

        it('disables the save button at first', () => {
          expect(findAddStreamBtn().props('disabled')).toBe(true);
        });

        it('displays the secret access key field when adding', async () => {
          await findSecretAccessKeyAddButton().trigger('click');

          expect(findSecretAccessKeyAddButton().props('disabled')).toBe(true);
          expect(findSecretAccessKeyCancelButton().exists()).toBe(true);
          expect(findSecretAccessKey().element.value).toBe('');
        });

        it('removes the secret access key field when cancelled', async () => {
          await findSecretAccessKeyAddButton().trigger('click');
          await findSecretAccessKeyCancelButton().trigger('click');

          expect(findSecretAccessKeyAddButton().props('disabled')).toBe(false);
          expect(findSecretAccessKey().exists()).toBe(false);
          expect(findSecretAccessKeyAddButton().exists()).toBe(true);
          expect(findSecretAccessKeyCancelButton().exists()).toBe(false);
        });
      });

      it.each`
        name                  | findInputFn
        ${'Destination Name'} | ${findName}
        ${'Access Key Xid'}   | ${findAccessKeyXid}
        ${'AWS Region'}       | ${findAwsRegion}
        ${'Bucket Name'}      | ${findBucketName}
      `('enable the save button when $name is edited', async ({ findInputFn }) => {
        createComponent({ props: { item: mockAmazonS3Destinations[0] } });

        expect(findAddStreamBtn().props('disabled')).toBe(true);

        await findInputFn().setValue('test');

        expect(findAddStreamBtn().props('disabled')).toBe(false);
      });

      it('should emit updated event after destination updated', async () => {
        createComponent({
          props: { item: mockAmazonS3Destinations[0] },
          apolloHandlers: [
            [
              amazonS3ConfigurationUpdate,
              jest.fn().mockResolvedValue(amazonS3DestinationUpdateMutationPopulator()),
            ],
          ],
        });

        findName().setValue(mockAmazonS3Destinations[0].name);
        findAccessKeyXid().setValue(mockAmazonS3Destinations[1].accessKeyXid);
        findAwsRegion().setValue(mockAmazonS3Destinations[1].awsRegion);
        findBucketName().setValue(mockAmazonS3Destinations[1].bucketName);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(0);
        expect(wrapper.emitted('error')).toBeUndefined();
        expect(wrapper.emitted('updated')).toBeDefined();
      });

      it('should emit updated event after destination secret access key updated', async () => {
        createComponent({
          props: { item: mockAmazonS3Destinations[0] },
          apolloHandlers: [
            [
              amazonS3ConfigurationUpdate,
              jest.fn().mockResolvedValue(amazonS3DestinationUpdateMutationPopulator()),
            ],
          ],
        });

        await findSecretAccessKeyAddButton().trigger('click');

        findSecretAccessKey().setValue(mockAmazonS3Destinations[1].secretAccessKey);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(0);
        expect(wrapper.emitted('error')).toBeUndefined();
        expect(wrapper.emitted('updated')).toBeDefined();
      });

      it('should not emit add destination event and reports error when server returns error', async () => {
        const errorMsg = 'Destination hosts limit exceeded';
        createComponent({
          props: { item: mockAmazonS3Destinations[0] },
          apolloHandlers: [
            [
              amazonS3ConfigurationUpdate,
              jest.fn().mockResolvedValue(amazonS3DestinationUpdateMutationPopulator([errorMsg])),
            ],
          ],
        });

        findName().setValue(mockAmazonS3Destinations[0].name);
        findAccessKeyXid().setValue(mockAmazonS3Destinations[0].accessKeyXid);
        findAwsRegion().setValue(mockAmazonS3Destinations[0].awsRegion);
        findBucketName().setValue(mockAmazonS3Destinations[0].bucketName);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(errorMsg);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('updated')).toBeUndefined();
      });

      it('should not emit add destination event and reports error when network error occurs', async () => {
        const sentryError = new Error('Network error');
        const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        createComponent({
          props: { item: mockAmazonS3Destinations[0] },
          apolloHandlers: [[amazonS3ConfigurationUpdate, jest.fn().mockRejectedValue(sentryError)]],
        });

        findName().setValue(mockAmazonS3Destinations[0].name);
        findAccessKeyXid().setValue(mockAmazonS3Destinations[0].accessKeyXid);
        findAwsRegion().setValue(mockAmazonS3Destinations[0].awsRegion);
        findBucketName().setValue(mockAmazonS3Destinations[0].bucketName);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.UPDATING_ERROR);
        expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('updated')).toBeUndefined();
      });
    });

    describe('deleting', () => {
      beforeEach(() => {
        createComponent({ props: { item: mockAmazonS3Destinations[0] } });
      });

      it('should emit deleted on success operation', async () => {
        const deleteButton = findDeleteBtn();
        await deleteButton.trigger('click');
        await findDeleteModal().vm.$emit('deleting');

        expect(deleteButton.props('loading')).toBe(true);

        await findDeleteModal().vm.$emit('delete');

        expect(deleteButton.props('loading')).toBe(false);
        expect(wrapper.emitted('deleted')).toEqual([[mockAmazonS3Destinations[0].id]]);
      });

      it('shows the alert for the error', () => {
        const errorMsg = 'An error occurred';
        findDeleteModal().vm.$emit('error', errorMsg);

        expect(createAlert).toHaveBeenCalledWith({
          message: AUDIT_STREAMS_NETWORK_ERRORS.DELETING_ERROR,
          captureError: true,
          error: errorMsg,
        });
      });
    });

    it('passes actual newlines when these are used in the secret access key input', async () => {
      const mutationMock = jest
        .fn()
        .mockResolvedValue(amazonS3DestinationCreateMutationPopulator());
      createComponent({
        apolloHandlers: [[amazonS3ConfigurationCreate, mutationMock]],
      });

      await findSecretAccessKey().setValue('\\ntest\\n');
      await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });

      expect(mutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          secretAccessKey: '\ntest\n',
        }),
      );
    });
  });
});
