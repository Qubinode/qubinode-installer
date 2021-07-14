# Qubinode Git branching  strategy

## Introduction

*This guide contains all the information needed to become a contributor on the Qubinode project#### Please follow our git branching model so that everyone will have a pleasant experience contributing to this project.*

## Branching and releasing

### Qubinode project Branches

The following are the only branches that will exists on the official Qubinode project (https://github.com/Qubinode):

- *main* holds the latest production ready code
* Rules:
** Should be the same for every Git user

- *develop* holds latest changes for next release
* Rules:
** Merge to *main*  branch when all codes are stable
** Tag *main* branch with new release number after merging from *develop* branch

### Qubinode supporting branches

The supporting branches will only exist on the developer's repository#### Once the code is ready to be pushed to either the main or develop branch#### Once the merge request is accepted, the developer can delete the supporting branch.

- *feature* holds code for developed new features that will be merged in the next or future Qubinode release
* Rules:
** May branch off from the *develop* branch
** Must merge back to the *develop* branch
** Exists on developer's repository only
** Discarded once all code are merged to *develop* bramch

- *release* support preparation of a new production release#### Use for minor changes or bugfixes
* Rules:
** May branch off from the *develop* branch
** Must merge back to the *develop* and *main* branch
** Exists on developer's repository only
** Only core developers can create and push release branch

- *hotfix* Use to push a fix for an error in the *main* branch
* Rules:
** May branch off from *main* branch
** Must be merged back into *main* and *develop* branch

## Scenerios

### Adding a new feature

#### switch to the develop branch:
```
$ git checkout develop
```

#### Fetch the latest code from the develop branch code:
```
$ git fetch develop
```

#### Create new feature branch using the nomenclature feature-<issue number>
```
$ git checkout -b feature-<issue number> develop
```

#### After coding, pushing new code to feature branch, checkout the develop branch
```
$ git checkout develop
```

#### Merge the new feature to the develop branch
```
$ git merge --no-ff feature-<issue number>
```

#### Delete the feature branch
```
$ git branch -d feature-<issue number>
```

#### Push changes to the develop branch
```
$ git push origin develop
```

#### Submit a merge request to the Qubinode repository

### HotFixes

#### switch to the main branch:
```
$ git checkout main
```

#### Create new hotfix branch using the nomenclature hotfix-<issue number>
```
$ git checkout -b hotfix-<issue number> main
```

#### After coding, pushing new code to feature branch, checkout the main branch
```
$ git checkout main
```

#### Merge the new hotfix to the Qubinode main branch
```
$ git merge --no-ff hotfix-<issue number>
```

#### Tag the Master branch with a new minor release version(if the current version is 2.1)
```
$ git tag -a <release minor release number>
```

#### Include bugfix to the develop branch, check out the develop branch
```
$ git checkout develop
```

#### Merge the new hotfix to the Qubinode develop main branch
```
$ git merge --no-ff hotfix-<issue number>
```

#### Delete the hotfix branch
```
$ git branch -d hotfix-<issue number>
```

### Pushing out a new release

After coding all features, hotfixes, and meet the requirement for the next Qubinode release, we will create a release branch that's tagged with a code name based on the next alphabetically available fruit ( i.e#### apple, banana)

#### Create new release branch using the fruit nomenclature
```
$ git checkout -b release-<fruit nomenclature, i.e apple> develop
```

#### Tag the release branch
```
$ git tag -a <fruit nomenclature, i.e apple>
```

#### Commit all changes to release branch
```
$ git commit -a -m "next qubinode release"
```

#### Merge all changes to main branch, check out the main branch
```
$ git checkout main
```

#### Merge changes to the main branch
```
$ git merge --no-ff release-<fruit nomenclature, i.e apple>
```

#### Tag the new release on the main branch
```
$ git tag -a <next release version i.e 2.2>
```

#### Update the develop branch with the new relase, checkout the develop branch
```
$ git checkout develop
```

#### Merge changes to develop branch
```
$ git merge --no-ff <next release version i.e 2.2>
```

#### Delete the release branch
```
$ git branch -d release-<fruit nomenclature, i.e apple>
```
