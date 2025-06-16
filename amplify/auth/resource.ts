import { defineAuth, defineFunction } from '@aws-amplify/backend';

export const auth = defineAuth({
  loginWith: {
    email: true,
    phone: true,
  },
  userAttributes: {
    email: {
      required: true
    },
    phoneNumber: {
      required: false
    },
    'custom:pubkey': {
      dataType: 'String',
      mutable: false,
    }
  },
});