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

/**
 * Enhanced search filters component with configurable filter visibility.
 *
 * Configuration options:
 * - hiddenFilters: Array of filter names to hide (e.g., ['subject', 'author'])
 * - allowedFilters: Array of filter names to show (if set, only these will be shown)
 * - scopeBasedFilters: Object mapping scope IDs to arrays of allowed filter names
 *   Use 'site-wide' as key for whole-site searches (when no specific scope is selected)
 * - entityBasedFilters: Object mapping entity types to arrays of allowed filter names
 *
 * Priority order:
 * 1. Scope-based filters (if current scope matches a key in scopeBasedFilters)
 *    - For site-wide searches, use 'site-wide' as the key
 * 2. Entity-based filters (if current entity type matches a key in entityBasedFilters)
 * 3. allowedFilters (if not empty, only these filters will be shown)
 * 4. hiddenFilters (hide these filters from the default set)
 *
 * Special case: 'subject' filter still uses original DQCheck logic combined with config
 */
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

  // Track logged filters to avoid duplicate logging
  private loggedFilters = new Set<string>();

  // Parameters to control which search filters are shown
  // Add the names of filters you want to hide to this array
  // Example: hiddenFilters = ['subject', 'author'];
  hiddenFilters: string[] = [];

  // Parameters to control which search filters are shown
  // If this array is not empty, only these filters will be shown
  // Example: allowedFilters = ['subject', 'dateIssued']; (will only show subject and dateIssued)
  // Leave empty to show all filters except those in hiddenFilters
  allowedFilters: string[] = [];

  // Parameters to control which filters are shown based on current scope (community/collection)
  // Key is the scope ID, value is array of filter names to show for that scope
  // Use 'site-wide' as the key for whole-site searches (when no specific scope is selected)
  // Example: scopeBasedFilters = {
  //   '57fd85d3-0b50-4239-8f05-8db5e0e65a6a': ['subject', 'author'],
  //   'site-wide': ['subject', 'author', 'dateIssued', 'type']
  // };
  scopeBasedFilters: { [scopeId: string]: string[] } = {
    'site-wide': [
      'subject',
      'author',
      'itemAffiliation',
      'itemFunder',
      'dateCreated',
      'itemClinicalSubject',
      'entityType',
      'committee'
    ],
    '3ba287c6-7a99-4ae4-807b-3cf10970033b': [
      'subject',
      'author',
      'itemAffiliation',
      'itemFunder',
      'dateCreated',
      'itemClinicalSubject',
      'itemQuality',
      'entityType',
      'subjectPop',
      'subjectDataModel',
      'subjectValidation',
      'subjectEvalType',
      'subjectMedTermChar',
    ],
    '6e29d087-aee0-4b50-8e2a-7aa3a0829e51': [
      'subject',
      'author',
      'itemAffiliation',
      'itemFunder',
      'dateCreated',
      'itemClinicalSubject',
      'entityType',
      'subjectPop',
      'subjectDataModel',
      'subjectValidation',
      'subjectEvalType',
      'subjectMedTermChar',
    ],
  };

  // Parameters to control which filters are shown based on entity type
  // Key is the entity type, value is array of filter names to show for that entity type
  // Example: entityBasedFilters = {'dqcheck': ['subject'], 'publication': ['author', 'dateIssued']};
  entityBasedFilters: { [entityType: string]: string[] } = {};

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

    // Debug logging for search filters initialization
    // console.log('=== Search Filters Component Init ===');
    // console.log('Current scope:', this.currentScope);
    // console.log('Current configuration:', this.currentConfiguration);
    // console.log('Entity type:', this.entityType);
    // console.log('Filter configuration:');
    // console.log('  - hiddenFilters:', this.hiddenFilters);
    // console.log('  - allowedFilters:', this.allowedFilters);
    // console.log('  - scopeBasedFilters:', this.scopeBasedFilters);
    // console.log('  - entityBasedFilters:', this.entityBasedFilters);
    // console.log('=== End Init Debug Info ===');

    // Log available filters when they become available
    if (this.filters) {
      this.filters.subscribe(filtersRD => {
        // console.log('=== Available Filters ===');
        const filters = filtersRD?.payload;
        // console.log('Total filters:', filters?.length || 0);

        // Extract unique filter names
        const uniqueFilterNames: string[] = [];
        if (filters) {
          filters.forEach((filter) => {
            if (!uniqueFilterNames.includes(filter.name)) {
              uniqueFilterNames.push(filter.name);
            }
          });
        }

        // console.log('Unique filter names:', uniqueFilterNames);
        // console.log('=== End Available Filters ===');
      });
    }
  }

  // Here we crudely filter the little sidebar search facet widgets
  // if we are either on the DQCheck community page or a DQCheck collection page
  shouldShowFilter(filter: { name: string }): boolean {
    // Only log each unique filter once
    if (!this.loggedFilters.has(filter.name)) {
      // console.log('Filter:', filter);
      this.loggedFilters.add(filter.name);
    }

    // Check if filter should be shown based on configuration arrays
    const shouldShowByConfig = this.shouldShowFilterByConfig(filter.name);

    // Original logic for DQCheck community/collection
    // const isDQCheckCommunity = this.currentScope === '57fd85d3-0b50-4239-8f05-8db5e0e65a6a';
    // const isDQCheckCollection =
    //   this.currentConfiguration === 'collection' && this.entityType === 'dqcheck';

    // For 'subject' filter, apply original logic
    // if (filter.name === 'subject') {
    //   const originalLogic = isDQCheckCommunity || isDQCheckCollection;
    //   return originalLogic && shouldShowByConfig;
    // }

    // For all other filters, use the configuration-based logic
    return shouldShowByConfig;
  }

  /**
   * Determine if a filter should be shown based on the configured parameters
   */
  shouldShowFilterByConfig(filterName: string): boolean {
    // Check scope-based filters first
    if (this.currentScope && this.scopeBasedFilters[this.currentScope]) {
      const scopeFilters = this.scopeBasedFilters[this.currentScope];
      return scopeFilters.includes(filterName);
    }

    // Check for site-wide search (when no specific scope is selected)
    if (!this.currentScope && this.scopeBasedFilters['site-wide']) {
      const siteWideFilters = this.scopeBasedFilters['site-wide'];
      return siteWideFilters.includes(filterName);
    }

    // Check entity-based filters
    if (this.entityType && this.entityBasedFilters[this.entityType]) {
      const entityFilters = this.entityBasedFilters[this.entityType];
      return entityFilters.includes(filterName);
    }

    // If allowedFilters is specified and not empty, only show those
    if (this.allowedFilters.length > 0) {
      return this.allowedFilters.includes(filterName);
    }

    // Otherwise, show all except those in hiddenFilters
    const isHidden = this.hiddenFilters.includes(filterName);
    return !isHidden;
  }
}
