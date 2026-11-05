import routeTests from './Routes.test';
import environmentTests from './Environment.test';
import contractTests from './Contract.test';
import domainTests from './Domain.test';
import repositoryTests from './Repository.test';
import viewModelTests from './ViewModel.test';
import profileViewModelTests from './ProfileViewModel.test';
import gameplayDataTests from './GameplayData.test';
import gameplayViewModelTests from './GameplayViewModel.test';
import gameplayAnswerDataTests from './GameplayAnswerData.test';
import gameplayAnswerViewModelTests from './GameplayAnswerViewModel.test';
import gameplayRefreshViewModelTests from './GameplayRefreshViewModel.test';

export default function testsuite(): void {
  routeTests();
  environmentTests();
  domainTests();
  contractTests();
  repositoryTests();
  viewModelTests();
  profileViewModelTests();
  gameplayDataTests();
  gameplayViewModelTests();
  gameplayAnswerDataTests();
  gameplayAnswerViewModelTests();
  gameplayRefreshViewModelTests();
}
