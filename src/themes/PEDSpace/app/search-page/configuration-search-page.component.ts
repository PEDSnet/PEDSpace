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

import { SearchConfigurationService } from '../../../../app/core/shared/search/search-configuration.service';
import { SEARCH_CONFIG_SERVICE } from '../../../../app/my-dspace-page/my-dspace-configuration.service';
import { ConfigurationSearchPageComponent as BaseComponent } from '../../../../app/search-page/configuration-search-page.component';
import { pushInOut } from '../../../../app/shared/animations/push';
import { SearchLabelsComponent } from '../../../../app/shared/search/search-labels/search-labels.component';
import { ThemedSearchResultsComponent } from '../../../../app/shared/search/search-results/themed-search-results.component';
import { ThemedSearchSidebarComponent } from '../../../../app/shared/search/search-sidebar/themed-search-sidebar.component';
import { ThemedSearchFormComponent } from '../../../../app/shared/search-form/themed-search-form.component';
import { PageWithSidebarComponent } from '../../../../app/shared/sidebar/page-with-sidebar.component';
import { ViewModeSwitchComponent } from '../../../../app/shared/view-mode-switch/view-mode-switch.component';
import { PedspaceViewToggleComponent } from '../shared/search/pedspace-view-toggle/pedspace-view-toggle.component';

@Component({
  selector: 'ds-themed-configuration-search-page',
  styleUrls: ['../shared/search/search.component.scss'],
  templateUrl: '../shared/search/search.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  animations: [pushInOut],
  providers: [
    {
      provide: SEARCH_CONFIG_SERVICE,
      useClass: SearchConfigurationService,
    },
  ],
  standalone: true,
  imports: [NgIf, NgTemplateOutlet, PageWithSidebarComponent, ViewModeSwitchComponent, ThemedSearchResultsComponent, ThemedSearchSidebarComponent, ThemedSearchFormComponent, SearchLabelsComponent, AsyncPipe, TranslateModule, PedspaceViewToggleComponent],
})

/**
 * This component renders a search page using a configuration as input.
 */
export class ConfigurationSearchPageComponent extends BaseComponent implements OnInit {
  /** Hide the scope selector on PEDSpace search pages. */
  override showScopeSelector = false;

  /** Public collection/community search pages (exclude selection widgets/modals). */
  get usePublicSearchLayout(): boolean {
    const router: Router = (this as any).router;
    const url = router?.url ?? '';
    const isPublicComcolRoute = url.includes('/communities/') || url.includes('/collections/');
    return !this.selectable
      && !this.fixedFilterQuery
      && isPublicComcolRoute;
  }

  ngOnInit(): void {
    super.ngOnInit();
    this.applyDefaultGridView();
  }

  /** Public page defaults: grid view, 12 results/page, most relevant sort. */
  protected applyDefaultGridView(): void {
    if (!isPlatformBrowser(this.platformId)) {
      return;
    }
    if (!this.usePublicSearchLayout) {
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
    const params = leaf?.queryParams ?? {};
    const queryParams: Record<string, string | number> = {};
    if (params.view !== 'grid') {
      queryParams.view = 'grid';
    }
    if (!params.size) {
      queryParams.size = 12;
    }
    if (!params.sortField) {
      queryParams.sortField = 'score';
    }
    if (!params.sortDirection) {
      queryParams.sortDirection = 'DESC';
    }
    if (Object.keys(queryParams).length === 0) {
      return;
    }
    void router.navigate([], {
      queryParams,
      queryParamsHandling: 'merge',
      replaceUrl: true,
    });
  }
}

