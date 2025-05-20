const baseMocks = [
  'invokeRESTMocks',
  'invokeSOAPMocks',
  'invokeGraphQLMocks',
  'invokeGRPCMocks',
  'invokeREST_HelloAPIMocks',
  'invokeREST_PetStoreAPI',
  'asyncAPI_websocketMocks',
]
export const flavorConfig = {
  regular-auth: ['ownAPIsAuth', ...baseMocks],
  regular-noauth: ['ownAPIsNoAuth', ...baseMocks],
  uber-jvm: ['ownAPIsNoAuth', ...baseMocks],
  uber-native: ['ownAPIsAuth', ...baseMocks.filter(fn => fn !== 'invokeSOAPMocks')],
  // add more flavors as needed…
};
