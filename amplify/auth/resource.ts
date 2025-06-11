import { defineAuth } from '@aws-amplify/backend';

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
  }
});
