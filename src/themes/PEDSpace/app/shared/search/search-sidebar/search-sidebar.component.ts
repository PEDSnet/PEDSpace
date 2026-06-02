/**
 * The contents of this file are subject to the license and copyright
 * detailed in the LICENSE_ATMIRE and NOTICE_ATMIRE files at the root of the source
 * tree and available online at
 *
 * https://www.atmire.com/software-license/
 */
import {
  AsyncPipe,
  NgIf,
} from '@angular/common';
import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

import { SearchConfigurationService } from '../../../../../../app/core/shared/search/search-configuration.service';
import { SEARCH_CONFIG_SERVICE } from '../../../../../../app/my-dspace-page/my-dspace-configuration.service';
import { AdvancedSearchComponent } from '../../../../../../app/shared/search/advanced-search/advanced-search.component';
import { ThemedSearchFiltersComponent } from '../../../../../../app/shared/search/search-filters/themed-search-filters.component';
import { ThemedSearchSettingsComponent } from '../../../../../../app/shared/search/search-settings/themed-search-settings.component';
import { SearchSidebarComponent as BaseComponent } from '../../../../../../app/shared/search/search-sidebar/search-sidebar.component';
import { SearchSwitchConfigurationComponent } from '../../../../../../app/shared/search/search-switch-configuration/search-switch-configuration.component';
import { ViewModeSwitchComponent } from '../../../../../../app/shared/view-mode-switch/view-mode-switch.component';
import { PedspaceViewToggleComponent } from '../pedspace-view-toggle/pedspace-view-toggle.component';


@Component({
  selector: 'ds-themed-search-sidebar',
  styleUrls: ['../../../../../../app/shared/search/search-sidebar/search-sidebar.component.scss'],
  templateUrl: './search-sidebar.component.html',
  providers: [
    {
      provide: SEARCH_CONFIG_SERVICE,
      useClass: SearchConfigurationService,
    },
  ],
  standalone: true,
  imports: [NgIf, ViewModeSwitchComponent, SearchSwitchConfigurationComponent, ThemedSearchFiltersComponent, ThemedSearchSettingsComponent, TranslateModule, AdvancedSearchComponent, AsyncPipe, PedspaceViewToggleComponent],
})
export class SearchSidebarComponent extends BaseComponent {
  /** UUID of the PEDSnet Studies community — the only scope that shows the project toggle. */
  readonly STUDIES_COMMUNITY_UUID = '92eba3a4-d7d3-43bd-b3f9-0f84c68c08f6';

  /**
   * True only when we're inside the Studies community AND the backend
   * reports that at least one result has a projectEndDate value (hasFacets).
   */
  get showProjectToggle$(): boolean {
        if (this.currentScope !== this.STUDIES_COMMUNITY_UUID) {
          return false;
        }
        return true;
  }
}
