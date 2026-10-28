import routeTests from './Routes.test';
import environmentTests from './Environment.test';
import contractTests from './Contract.test';
import domainTests from './Domain.test';
import repositoryTests from './Repository.test';
import viewModelTests from './ViewModel.test';

export default function testsuite(): void {
  routeTests();
  environmentTests();
  domainTests();
  contractTests();
  repositoryTests();
  viewModelTests();
}
