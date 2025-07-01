import {
  AsyncPipe,
  NgFor,
  NgIf,
} from '@angular/common';
import {
  Component,
  Inject,
  OnInit,
} from '@angular/core';
import {
  ActivatedRoute,
  Router,
  RouterLink,
} from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { NgxSkeletonLoaderModule } from 'ngx-skeleton-loader';
import { SearchService } from 'src/app/core/shared/search/search.service';
import { SearchConfigurationService } from 'src/app/core/shared/search/search-configuration.service';
import { SearchFilterService } from 'src/app/core/shared/search/search-filter.service';
import { SEARCH_CONFIG_SERVICE } from 'src/app/my-dspace-page/my-dspace-configuration.service';
import { AdvancedSearchComponent } from 'src/app/shared/search/advanced-search/advanced-search.component';
import { SearchFilterComponent } from 'src/app/shared/search/search-filters/search-filter/search-filter.component';
import { SearchFiltersComponent as BaseComponent } from 'src/app/shared/search/search-filters/search-filters.component';
import {
  APP_CONFIG,
  AppConfig,
} from 'src/config/app-config.interface';

@Component({
  selector: 'ds-themed-search-filters',
  templateUrl: './search-filters.component.html',
  styleUrls: ['./search-filters.component.scss'],
  standalone: true,
  providers: [{ provide: SEARCH_CONFIG_SERVICE, useClass: SearchConfigurationService }],
  imports: [
    NgIf,
    NgFor,
    SearchFilterComponent,
    RouterLink,
    AsyncPipe,
    TranslateModule,
    NgxSkeletonLoaderModule,
    AdvancedSearchComponent,
  ],
})
export class SearchFiltersComponent extends BaseComponent implements OnInit {
  /** pulled once from the resolver */
  public entityType: string;

  constructor(
    protected searchService: SearchService,
    protected searchFilterService: SearchFilterService,
    protected router: Router,
    @Inject(SEARCH_CONFIG_SERVICE) protected searchConfigService: SearchConfigurationService,
    @Inject(APP_CONFIG) protected appConfig: AppConfig,
    private route: ActivatedRoute,
  ) {
    super(searchService, searchFilterService, router, searchConfigService, appConfig);
  }

  ngOnInit(): void {
    super.ngOnInit();
    // climb until we find the route with `data.dso`
    let r: ActivatedRoute | null = this.route;
    while (r && !r.snapshot.data.dso) {
      r = r.parent;
    }
    if (r?.snapshot.data.dso) {
      const dso = r.snapshot.data.dso;
      const md = dso.payload.metadata['dspace.entity.type'];
      this.entityType = md?.[0]?.value?.toLowerCase() ?? null;
    }
  }

  // Here we crudely filter the little sidebar search facet widgets
  // if we are either on the DQCheck community page or a DQCheck collection page
  shouldShowFilter(filter: { name: string }): boolean {
    // console.log('shouldShowFilter', filter);
    if (filter.name !== 'subject') {
      return true;
    }
    const isDQCheckCommunity = this.currentScope === '57fd85d3-0b50-4239-8f05-8db5e0e65a6a';
    const isDQCheckCollection =
      this.currentConfiguration === 'collection' && this.entityType === 'dqcheck';
    return isDQCheckCommunity || isDQCheckCollection;
  }
}
