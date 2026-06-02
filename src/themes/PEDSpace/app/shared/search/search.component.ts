import {
  AsyncPipe,
  isPlatformBrowser,
  NgIf,
  NgTemplateOutlet,
} from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  OnInit,
} from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import { pushInOut } from '../../../../../app/shared/animations/push';
import { SearchComponent as BaseComponent } from '../../../../../app/shared/search/search.component';
import { SearchLabelsComponent } from '../../../../../app/shared/search/search-labels/search-labels.component';
import { ThemedSearchResultsComponent } from '../../../../../app/shared/search/search-results/themed-search-results.component';
import { ThemedSearchSidebarComponent } from '../../../../../app/shared/search/search-sidebar/themed-search-sidebar.component';
import { ThemedSearchFormComponent } from '../../../../../app/shared/search-form/themed-search-form.component';
import { PageWithSidebarComponent } from '../../../../../app/shared/sidebar/page-with-sidebar.component';
import { ViewModeSwitchComponent } from '../../../../../app/shared/view-mode-switch/view-mode-switch.component';
import { PedspaceViewToggleComponent } from './pedspace-view-toggle/pedspace-view-toggle.component';

@Component({
  selector: 'ds-themed-search',
  styleUrls: ['./search.component.scss'],
  templateUrl: './search.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  animations: [pushInOut],
  standalone: true,
  imports: [
    AsyncPipe,
    NgIf,
    NgTemplateOutlet,
    PageWithSidebarComponent,
    ThemedSearchFormComponent,
    ThemedSearchResultsComponent,
    ThemedSearchSidebarComponent,
    TranslateModule,
    SearchLabelsComponent,
    ViewModeSwitchComponent,
    PedspaceViewToggleComponent,
  ],
})
export class SearchComponent extends BaseComponent implements OnInit {
  ngOnInit(): void {
    super.ngOnInit();
    this.applyDefaultGridView();
  }

  /** Default the results view to grid when no `view` query param is set (#176). */
  protected applyDefaultGridView(): void {
    if (!isPlatformBrowser(this.platformId)) {
      return;
    }
    const router: Router = (this as any).router;
    if (!router) {
      return;
    }
    let leaf = router.routerState?.snapshot?.root;
    while (leaf?.firstChild) {
      leaf = leaf.firstChild;
    }
    if (leaf?.queryParams?.view) {
      return;
    }
    void router.navigate([], {
      queryParams: { view: 'grid' },
      queryParamsHandling: 'merge',
      replaceUrl: true,
    });
  }
}
