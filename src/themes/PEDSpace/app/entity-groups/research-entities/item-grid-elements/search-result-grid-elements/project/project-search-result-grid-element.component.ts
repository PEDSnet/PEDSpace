import {
  AsyncPipe,
  NgIf,
} from '@angular/common';
import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import { Context } from '../../../../../../../../app/core/shared/context.model';
import { ViewMode } from '../../../../../../../../app/core/shared/view-mode.model';
import { focusShadow } from '../../../../../../../../app/shared/animations/focus';
import { ItemSearchResult } from '../../../../../../../../app/shared/object-collection/shared/item-search-result.model';
import { ThemedBadgesComponent } from '../../../../../../../../app/shared/object-collection/shared/badges/themed-badges.component';
import { listableObjectComponent } from '../../../../../../../../app/shared/object-collection/shared/listable-object/listable-object.decorator';
import { ItemSearchResultGridElementComponent } from '../../../../../../../../app/shared/object-grid/search-result-grid-element/item-search-result/item/item-search-result-grid-element.component';
import { TruncatableComponent } from '../../../../../../../../app/shared/truncatable/truncatable.component';
import { TruncatablePartComponent } from '../../../../../../../../app/shared/truncatable/truncatable-part/truncatable-part.component';

/**
 * PEDSpace-themed grid card for item search results (#176).
 *
 * Layout:
 *   [ startDate-endDate OR year ] [ entity-type badge ]
 *   <linked title>
 *   Lead Site: <local.contributor.siteLead>
 *   <dc.description.abstract>
 *
 * Registered for plain Item / Publication / Project / Study results so every
 * community page result shares the same look.
 */
@listableObjectComponent(ItemSearchResult, ViewMode.GridElement, Context.Any, 'PEDSpace')
@listableObjectComponent('PublicationSearchResult', ViewMode.GridElement, Context.Any, 'PEDSpace')
@listableObjectComponent('ProjectSearchResult', ViewMode.GridElement, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-pedspace-project-search-result-grid-element',
  styleUrls: ['./project-search-result-grid-element.component.scss'],
  templateUrl: './project-search-result-grid-element.component.html',
  animations: [focusShadow],
  standalone: true,
  imports: [TruncatableComponent, NgIf, RouterLink, ThemedBadgesComponent, TruncatablePartComponent, AsyncPipe, TranslateModule],
})
export class ProjectSearchResultGridElementComponent extends ItemSearchResultGridElementComponent {

  get startDate(): string {
    return this.firstMetadataValue('project.startDate');
  }

  get endDate(): string {
    return this.firstMetadataValue('project.endDate');
  }

  /**
   * Mint-pill date label. Prefers `project.startDate - project.endDate`; falls
   * back to year of `dc.date.issued` so every card shows a date as in the mockup.
   */
  get dateRange(): string {
    const start = this.startDate;
    const end = this.endDate;
    if (start || end) {
      if (start && end) {
        return `${start} - ${end}`;
      }
      return start || end;
    }
    const issued = this.firstMetadataValue('dc.date.issued');
    if (!issued) {
      return '';
    }
    const yearMatch = issued.match(/\d{4}/);
    return yearMatch ? yearMatch[0] : issued;
  }

  get leadSite(): string {
    return this.firstMetadataValue('local.contributor.siteLead');
  }

  get abstract(): string {
    return this.firstMetadataValue('dc.description.abstract');
  }

  /**
   * Plain item name. Avoids the hit-highlighted, comma-joined string from the
   * base item grid template that caused leading-comma artifacts.
   */
  get plainTitle(): string {
    return this.dsoNameService.getName(this.dso);
  }
}
