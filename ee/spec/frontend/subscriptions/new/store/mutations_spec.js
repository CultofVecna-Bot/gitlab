import mutations from 'ee/subscriptions/new/store/mutations';
import * as types from 'ee/subscriptions/new/store/mutation_types';

const state = () => ({
  currentStep: 'firstStep',
  selectedPlan: 'firstPlan',
  isSetupForCompany: true,
  numberOfUsers: 1,
  organizationName: 'name',
  countryOptions: [],
  stateOptions: [],
});

let stateCopy;

beforeEach(() => {
  stateCopy = state();
});

describe('ee/subscriptions/new/store/mutation', () => {
  describe.each`
    mutation                                | value                                 | stateProp
    ${types.UPDATE_CURRENT_STEP}            | ${'secondStep'}                       | ${'currentStep'}
    ${types.UPDATE_SELECTED_PLAN}           | ${'secondPlan'}                       | ${'selectedPlan'}
    ${types.UPDATE_IS_SETUP_FOR_COMPANY}    | ${false}                              | ${'isSetupForCompany'}
    ${types.UPDATE_NUMBER_OF_USERS}         | ${2}                                  | ${'numberOfUsers'}
    ${types.UPDATE_ORGANIZATION_NAME}       | ${'new name'}                         | ${'organizationName'}
    ${types.UPDATE_COUNTRY_OPTIONS}         | ${[{ text: 'country', value: 'id' }]} | ${'countryOptions'}
    ${types.UPDATE_STATE_OPTIONS}           | ${[{ text: 'state', value: 'id' }]}   | ${'stateOptions'}
    ${types.UPDATE_COUNTRY}                 | ${'NL'}                               | ${'country'}
    ${types.UPDATE_STREET_ADDRESS_LINE_ONE} | ${'streetAddressLine1'}               | ${'streetAddressLine1'}
    ${types.UPDATE_STREET_ADDRESS_LINE_TWO} | ${'streetAddressLine2'}               | ${'streetAddressLine2'}
    ${types.UPDATE_CITY}                    | ${'city'}                             | ${'city'}
    ${types.UPDATE_COUNTRY_STATE}           | ${'countryState'}                     | ${'countryState'}
    ${types.UPDATE_ZIP_CODE}                | ${'zipCode'}                          | ${'zipCode'}
  `('$mutation', ({ mutation, value, stateProp }) => {
    it(`should set the ${stateProp} to the given value`, () => {
      expect(stateCopy[stateProp]).not.toEqual(value);

      mutations[mutation](stateCopy, value);

      expect(stateCopy[stateProp]).toEqual(value);
    });
  });
});

describe('UPDATE_PAYMENT_FORM_PARAMS', () => {
  it('should set the paymentFormParams to the given paymentFormParams', () => {
    mutations[types.UPDATE_PAYMENT_FORM_PARAMS](stateCopy, { token: 'x' });

    expect(stateCopy.paymentFormParams).toEqual({ token: 'x' });
  });
});

describe('UPDATE_PAYMENT_METHOD_ID', () => {
  it('should set the paymentMethodId to the given paymentMethodId', () => {
    mutations[types.UPDATE_PAYMENT_METHOD_ID](stateCopy, 'paymentMethodId');

    expect(stateCopy.paymentMethodId).toEqual('paymentMethodId');
  });
});

describe('UPDATE_CREDIT_CARD_DETAILS', () => {
  it('should set the creditCardDetails to the given creditCardDetails', () => {
    mutations[types.UPDATE_CREDIT_CARD_DETAILS](stateCopy, { type: 'x' });

    expect(stateCopy.creditCardDetails).toEqual({ type: 'x' });
  });
});
