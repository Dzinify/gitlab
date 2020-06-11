import { getChangesCountForFiles, filePathMatches } from './utils';
import {
  leftSidebarViews,
  packageJsonPath,
  PERMISSION_READ_MR,
  PERMISSION_CREATE_MR,
  PERMISSION_PUSH_CODE,
} from '../constants';

export const activeFile = state => state.openFiles.find(file => file.active) || null;

export const addedFiles = state => state.changedFiles.filter(f => f.tempFile);

export const modifiedFiles = state => state.changedFiles.filter(f => !f.tempFile);

export const currentMergeRequest = state =>
  state.project?.mergeRequests?.[state.currentMergeRequestId];

export const currentProject = state => state.project;

export const emptyRepo = state => state.project?.empty_repo;

export const currentTree = state => state.fileSystem.files[''];

export const hasMergeRequest = state => Boolean(state.currentMergeRequestId);

export const allBlobs = state =>
  Object.keys(state.entries)
    .reduce((acc, key) => {
      const entry = state.entries[key];

      if (entry.type === 'blob') {
        acc.push(entry);
      }

      return acc;
    }, [])
    .sort((a, b) => b.lastOpenedAt - a.lastOpenedAt);

export const getChangedFile = state => path => state.changedFiles.find(f => f.path === path);
export const getStagedFile = state => path => state.stagedFiles.find(f => f.path === path);
export const getOpenFile = state => path => state.openFiles.find(f => f.path === path);

export const lastOpenedFile = state =>
  [...state.changedFiles, ...state.stagedFiles].sort((a, b) => b.lastOpenedAt - a.lastOpenedAt)[0];

export const isEditModeActive = state => state.currentActivityView === leftSidebarViews.edit.name;
export const isCommitModeActive = state =>
  state.currentActivityView === leftSidebarViews.commit.name;
export const isReviewModeActive = state =>
  state.currentActivityView === leftSidebarViews.review.name;

export const someUncommittedChanges = state =>
  Boolean(state.changedFiles.length || state.stagedFiles.length);

export const getChangesInFolder = state => path => {
  const changedFilesCount = state.changedFiles.filter(f => filePathMatches(f.path, path)).length;
  const stagedFilesCount = state.stagedFiles.filter(
    f => filePathMatches(f.path, path) && !getChangedFile(state)(f.path),
  ).length;

  return changedFilesCount + stagedFilesCount;
};

export const getUnstagedFilesCountForPath = state => path =>
  getChangesCountForFiles(state.changedFiles, path);

export const getStagedFilesCountForPath = state => path =>
  getChangesCountForFiles(state.stagedFiles, path);

export const lastCommit = (state, getters) => {
  const branch = getters.currentProject && getters.currentBranch;

  return branch ? branch.commit : null;
};

export const findBranch = state => branchId => state.project?.branches[branchId];

export const currentBranch = (state, getters) => getters.findBranch(state.currentBranchId);

export const branchName = (_state, getters) => getters.currentBranch && getters.currentBranch.name;

export const packageJson = state => state.entries[packageJsonPath];

export const isOnDefaultBranch = (_state, getters) =>
  getters.currentProject && getters.currentProject.default_branch === getters.branchName;

export const canPushToBranch = (_state, getters) => {
  return Boolean(getters.currentBranch ? getters.currentBranch.can_push : getters.canPushCode);
};

export const isFileDeletedAndReadded = (state, getters) => path => {
  const stagedFile = getters.getStagedFile(path);
  const file = state.entries[path];
  return Boolean(stagedFile && stagedFile.deleted && file.tempFile);
};

// checks if any diff exists in the staged or unstaged changes for this path
export const getDiffInfo = (state, getters) => path => {
  const stagedFile = getters.getStagedFile(path);
  const file = state.entries[path];
  const renamed = file.prevPath ? file.path !== file.prevPath : false;
  const deletedAndReadded = getters.isFileDeletedAndReadded(path);
  const deleted = deletedAndReadded ? false : file.deleted;
  const tempFile = deletedAndReadded ? false : file.tempFile;
  const changed = file.content !== (deletedAndReadded ? stagedFile.raw : file.raw);

  return {
    exists: changed || renamed || deleted || tempFile,
    changed,
    renamed,
    deleted,
    tempFile,
  };
};

export const projectPermissions = state => state.project?.userPermissions || {};

export const canReadMergeRequests = (state, getters) =>
  Boolean(getters.projectPermissions[PERMISSION_READ_MR]);

export const canCreateMergeRequests = (state, getters) =>
  Boolean(getters.projectPermissions[PERMISSION_CREATE_MR]);

export const canPushCode = (state, getters) =>
  Boolean(getters.projectPermissions[PERMISSION_PUSH_CODE]);

export const entryExists = state => path =>
  Boolean(state.entries[path] && !state.entries[path].deleted);

export const getAvailableFileName = (state, getters) => path => {
  let newPath = path;

  while (getters.entryExists(newPath)) {
    newPath = newPath.replace(
      /([ _-]?)(\d*)(\..+?$|$)/,
      (_, before, number, after) => `${before || '_'}${Number(number) + 1}${after}`,
    );
  }

  return newPath;
};
