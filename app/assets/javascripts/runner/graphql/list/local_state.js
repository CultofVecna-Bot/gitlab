import { makeVar } from '@apollo/client/core';
import { RUNNER_TYPENAME } from '../../constants';
import typeDefs from './typedefs.graphql';

/**
 * Local state for checkable runner items.
 *
 * Usage:
 *
 * ```
 * import { createLocalState } from '~/runner/graphql/list/local_state';
 *
 * // initialize local state
 * const { cacheConfig, typeDefs, localMutations } = createLocalState();
 *
 * // configure the client
 * apolloClient = createApolloClient({}, { cacheConfig, typeDefs });
 *
 * // modify local state
 * localMutations.setRunnerChecked( ... )
 * ```
 *
 * Note: Currently only in use behind a feature flag:
 * admin_runners_bulk_delete for the admin list, rollout issue:
 * https://gitlab.com/gitlab-org/gitlab/-/issues/353981
 *
 * @returns {Object} An object to configure an Apollo client:
 * contains cacheConfig, typeDefs, localMutations.
 */
export const createLocalState = () => {
  const checkedRunnerIdsVar = makeVar({});

  const cacheConfig = {
    typePolicies: {
      Query: {
        fields: {
          checkedRunnerIds(_, { canRead, toReference }) {
            return Object.entries(checkedRunnerIdsVar())
              .filter(([id]) => {
                // Some runners may be deleted by the user separately.
                // Skip dangling references, those not in the cache.
                // See: https://www.apollographql.com/docs/react/caching/garbage-collection/#dangling-references
                return canRead(toReference({ __typename: RUNNER_TYPENAME, id }));
              })
              .filter(([, isChecked]) => isChecked)
              .map(([id]) => id);
          },
        },
      },
    },
  };

  const localMutations = {
    setRunnerChecked({ runner, isChecked }) {
      checkedRunnerIdsVar({
        ...checkedRunnerIdsVar(),
        [runner.id]: isChecked,
      });
    },
    clearChecked() {
      checkedRunnerIdsVar({});
    },
  };

  return {
    cacheConfig,
    typeDefs,
    localMutations,
  };
};
