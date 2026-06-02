import {
  AsyncPipe,
  NgIf,
} from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  Inject,
  OnDestroy,
  OnInit,
  PLATFORM_ID,
} from '@angular/core';
import {
  ActivatedRoute,
  Params,
  Router,
} from '@angular/router';
import {
  BehaviorSubject,
  combineLatest,
  Subscription,
} from 'rxjs';
import { TranslateModule } from '@ngx-translate/core';

import { SEARCH_CONFIG_SERVICE } from '../../../../../../app/my-dspace-page/my-dspace-configuration.service';
import { SearchConfigurationService } from '../../../../../../app/core/shared/search/search-configuration.service';

type ProjectViewMode = 'all' | 'past' | 'active';

/**
 * Past / All / Active toggle for project-based community searches (#176).
 *
 * Uses `f.projectEndDate` with `equals`/`notequals` operators:
 *
 *   Active: f.projectEndDate=Present,equals   (end date is "Present" → ongoing)
 *   Past:   f.projectEndDate=Present,notequals (end date is a year → ended)
 *   All:    param removed
 */
@Component({
  selector: 'ds-pedspace-view-toggle',
  templateUrl: './pedspace-view-toggle.component.html',
  styleUrls: ['./pedspace-view-toggle.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: true,
  imports: [AsyncPipe, NgIf, TranslateModule],
})
export class PedspaceViewToggleComponent implements OnInit, OnDestroy {
  /** URL query param for the project end-date filter. */
  static readonly FILTER_FIELD = 'f.projectEndDate';
  static readonly PRESENT_EQUALS = 'Present,equals';
  static readonly PRESENT_NOTEQUALS = 'Present,notequals';

  currentMode$: BehaviorSubject<ProjectViewMode> = new BehaviorSubject<ProjectViewMode>('all');
  visible$: BehaviorSubject<boolean> = new BehaviorSubject<boolean>(false);

  protected subs: Subscription[] = [];

  constructor(
    @Inject(SEARCH_CONFIG_SERVICE) protected searchConfigService: SearchConfigurationService,
    protected router: Router,
    protected route: ActivatedRoute,
    @Inject(PLATFORM_ID) protected platformId: any,
  ) {}

  ngOnInit(): void {
    this.subs.push(combineLatest([
      this.route.queryParamMap,
      this.searchConfigService.getCurrentConfiguration(''),
    ]).subscribe(([params, _configuration]) => {
      this.visible$.next(true);
      const endDateVal = params.get(PedspaceViewToggleComponent.FILTER_FIELD);
      if (endDateVal === PedspaceViewToggleComponent.PRESENT_EQUALS) {
        this.currentMode$.next('active');
      } else if (endDateVal === PedspaceViewToggleComponent.PRESENT_NOTEQUALS) {
        this.currentMode$.next('past');
      } else {
        this.currentMode$.next('all');
      }
    }));
  }

  setMode(mode: ProjectViewMode): void {
    const field = PedspaceViewToggleComponent.FILTER_FIELD;
    const queryParams: Params = {
      page: null,
      // also clear any leftover projectStartDate range params
      'f.projectStartDate.min': null,
      'f.projectStartDate.max': null,
      [field]: null,
    };
    if (mode === 'active') {
      queryParams[field] = PedspaceViewToggleComponent.PRESENT_EQUALS;
    } else if (mode === 'past') {
      queryParams[field] = PedspaceViewToggleComponent.PRESENT_NOTEQUALS;
    }
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams,
      queryParamsHandling: 'merge',
    });
  }

  ngOnDestroy(): void {
    this.subs.forEach((s) => s.unsubscribe());
  }
}
