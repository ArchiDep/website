import {
  horizontalLayoutExtensionPredicate,
  Memoir,
  MemoirBuilder
} from 'git-memoir';

(function () {
  const gitMemoirs: Record<string, () => Memoir> = window['gitMemoirs'] ?? {};
  window['gitMemoirs'] = gitMemoirs;

  function createBranchingBaseMemoir() {
    return new MemoirBuilder()

      .fileSystem('demo')
      .repo('demo', { mainBranch: 'main' })

      .chapter('setup', {
        before: function (_step, drawer) {
          drawer.requireExtension(
            horizontalLayoutExtensionPredicate
          ).minRepositoryGridColumns = 3;
          drawer.requireExtension(
            horizontalLayoutExtensionPredicate
          ).uniformRepositoryGridColumnWidth = true;
          drawer.requireExtension(
            horizontalLayoutExtensionPredicate
          ).uniformRepositoryGridColumnWidthAcrossFileSystems = true;
        }
      })
      .commit({ commit: { hash: '387f12' } })

      .chapter('commits')
      .commit({ commit: { hash: '9ab3fd' } })
      .commit({ commit: { hash: '4f94fa' } })

      .chapter('branch')
      .branch('feature-sub')

      .chapter('checkout')
      .checkout('feature-sub')

      .chapter('commit-on-a-branch-width', {
        before: function (_step, drawer) {
          drawer.requireExtension(
            horizontalLayoutExtensionPredicate
          ).minRepositoryGridColumns = 4;
        }
      })

      .chapter('commit-on-a-branch')
      .commit({ commit: { hash: '712ff2' } })

      .chapter('back-to-main')
      .checkout('main')

      .chapter('another-branch')
      .checkout('fix-add', { new: true });
  }

  gitMemoirs['internals'] = function () {
    return new MemoirBuilder()
      .chapter('internals', {
        before: (_step, drawer) => {
          drawer
            .requireExtension(horizontalLayoutExtensionPredicate)
            .setBlobsVisible(false)
            .setBranchesVisible(false)
            .setTreesVisible(true);
        }
      })
      .fileSystem('demo', fs => {
        fs.write('demo/file1', 'data1');
      })
      .repo('demo', {})
      .add('file1')
      .commit({ commit: { hash: '387f12' } })
      .fileSystem('demo', fs => {
        fs.write('demo/file1', 'data2');
      })
      .add('file1')
      .commit({ commit: { hash: '9ab3fd' } })
      .fileSystem('demo', fs => {
        fs.write('demo/file1', 'data3');
      })
      .add('file1')
      .commit({ commit: { hash: '4f94fa' } }).memoir;
  };

  gitMemoirs['branchingOneLine'] = function () {
    return createBranchingBaseMemoir()
      .chapter('padding')
      .checkout('feature-sub')
      .commit()
      .commit().memoir;
  };

  gitMemoirs['branching'] = function () {
    return (
      createBranchingBaseMemoir()
        .chapter('divergent-history-settings', {
          before: function (_step, drawer) {
            drawer.requireExtension(
              horizontalLayoutExtensionPredicate
            ).minRepositoryGridRows = 2;
          }
        })

        .chapter('divergent-history')
        .commit({ commit: { hash: '2817bc' } })

        .chapter('switch-branches')
        .checkout('feature-sub')
        .checkout('fix-add')

        .chapter('fast-forward-merge-checkout')
        .checkout('main')

        .chapter('fast-forward-merge')
        .merge('fix-add')

        .chapter('delete-branch')
        .branch('fix-add', { delete: true })

        .chapter('work-on-feature-branch-settings', {
          before: function (_step, drawer) {
            drawer.requireExtension(
              horizontalLayoutExtensionPredicate
            ).minRepositoryGridColumns = 5;
          }
        })

        .chapter('work-on-feature-branch')
        .checkout('feature-sub')
        .commit({ commit: { hash: 'f92ab0' } })

        // Disable uniform column width for later steps (or the commit graph gets too wide)
        // .chapter('column-width-settings', {
        // before: function(step, drawer) {
        //   drawer.requireExtension(horizontalLayoutExtensionPredicate).getRepositoryGridLayoutStrategy().uniformColumnWidth = false;
        // }
        // })

        .chapter('merge-checkout')
        .checkout('main')

        .chapter('merge-settings', {
          before: function (_step, drawer) {
            drawer.requireExtension(
              horizontalLayoutExtensionPredicate
            ).minRepositoryGridColumns = 6;
          }
        })

        .chapter('merge')
        .merge('feature-sub', { commit: { hash: '04fb82' } })

        .chapter('delete-feature-sub')
        .branch('feature-sub', { delete: true })

        .chapter('checkout-past')
        .checkout('better-sub', { new: true, refspec: '4f94fa' })

        .chapter('conflicting-change-settings', {
          before: function (_step, drawer) {
            drawer.requireExtension(
              horizontalLayoutExtensionPredicate
            ).minRepositoryGridRows = 3;
          }
        })

        .chapter('conflicting-change')
        .commit({ commit: { hash: '98ff62' } })

        .chapter('merge-conflicting-change-settings', {
          before: function (_step, drawer) {
            drawer.requireExtension(
              horizontalLayoutExtensionPredicate
            ).minRepositoryGridColumns = 7;
          }
        })

        .chapter('merge-conflicting-change')
        .checkout('main')
        .merge('better-sub')
        .branch('better-sub', { delete: true })

        .chapter('conflicting-file-change-checkout')
        .checkout('cleanup', { new: true, refspec: '4f94fa' })

        .chapter('conflicting-file-change-settings', {
          before: function (_step, drawer) {
            drawer.requireExtension(
              horizontalLayoutExtensionPredicate
            ).minRepositoryGridRows = 4;
          }
        })

        .chapter('conflicting-file-change')
        .commit({ commit: { hash: '12ac65' } })

        .chapter('merge-conflicting-file-change-checkout')
        .checkout('main')

        .chapter('merge-conflicting-file-change-settings', {
          before: function (_step, drawer) {
            drawer.requireExtension(
              horizontalLayoutExtensionPredicate
            ).minRepositoryGridColumns = 8;
          }
        })

        .chapter('merge-conflicting-file-change')
        .merge('cleanup')
        .branch('cleanup', { delete: true }).memoir
    );
  };
})();
