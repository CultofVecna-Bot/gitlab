import {
  keysFor,
  PROJECT_FILES_MOVE_SELECTION_UP,
  PROJECT_FILES_MOVE_SELECTION_DOWN,
  PROJECT_FILES_OPEN_SELECTION,
  PROJECT_FILES_GO_BACK,
} from '~/behaviors/shortcuts/keybindings';
import ShortcutsNavigation from './shortcuts_navigation';

export default class ShortcutsFindFile extends ShortcutsNavigation {
  constructor(projectFindFile) {
    super();

    this.addStopCallback((e, element, combo) => {
      if (
        element === projectFindFile.inputElement[0] &&
        (keysFor(PROJECT_FILES_MOVE_SELECTION_UP).includes(combo) ||
          keysFor(PROJECT_FILES_MOVE_SELECTION_DOWN).includes(combo) ||
          keysFor(PROJECT_FILES_GO_BACK).includes(combo) ||
          keysFor(PROJECT_FILES_OPEN_SELECTION).includes(combo))
      ) {
        // when press up/down key in textbox, cursor prevent to move to home/end
        e.preventDefault();
        return false;
      }

      return undefined;
    });

    this.bindCommands([
      [PROJECT_FILES_MOVE_SELECTION_UP, projectFindFile.selectRowUp],
      [PROJECT_FILES_MOVE_SELECTION_DOWN, projectFindFile.selectRowDown],
      [PROJECT_FILES_GO_BACK, projectFindFile.goToTree],
      [PROJECT_FILES_OPEN_SELECTION, projectFindFile.goToBlob],
    ]);
  }
}
