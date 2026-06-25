import {
  AsyncPipe,
  CommonModule,
  KeyValuePipe,
  NgFor,
  NgIf,
} from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  inject,
  OnInit,
} from '@angular/core';
import { RouterLink } from '@angular/router';
import { NgbNavModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';
import {
  BehaviorSubject,
  Observable,
} from 'rxjs';
import { map } from 'rxjs/operators';
// import copy from 'copy-to-clipboard';
import { ThemedBadgesComponent } from 'src/app/shared/object-collection/shared/badges/themed-badges.component';

import { BitstreamDataService } from 'src/app/core/data/bitstream-data.service';
import { getFirstCompletedRemoteData } from 'src/app/core/shared/operators';
import { ItemHeroBannerComponent } from '../../item-hero-banner/item-hero-banner.component';

import { Context } from '../../../../../../../app/core/shared/context.model';
import { ViewMode } from '../../../../../../../app/core/shared/view-mode.model';
import { CollectionsComponent } from '../../../../../../../app/item-page/field-components/collections/collections.component';
import { ThemedMediaViewerComponent } from '../../../../../../../app/item-page/media-viewer/themed-media-viewer.component';
import { MiradorViewerComponent } from '../../../../../../../app/item-page/mirador-viewer/mirador-viewer.component';
import { ThemedFileSectionComponent } from '../../../../../../../app/item-page/simple/field-components/file-section/themed-file-section.component';
import { ItemPageAbstractFieldComponent } from '../../../../../../../app/item-page/simple/field-components/specific-field/abstract/item-page-abstract-field.component';
import { ItemPageCcLicenseFieldComponent } from '../../../../../../../app/item-page/simple/field-components/specific-field/cc-license/item-page-cc-license-field.component';
import { ItemPageCitationFieldComponent } from '../../../../../../../app/item-page/simple/field-components/specific-field/citation/item-page-citation-field.component';
import { ItemPageDateFieldComponent } from '../../../../../../../app/item-page/simple/field-components/specific-field/date/item-page-date-field.component';
import { ItemPageFunderFieldComponent } from '../../../../../../../app/item-page/simple/field-components/specific-field/funder/item-page-funder-field.component';
import { GenericItemPageFieldComponent } from '../../../../../../../app/item-page/simple/field-components/specific-field/generic/generic-item-page-field.component';
import { ThemedItemPageTitleFieldComponent } from '../../../../../../../app/item-page/simple/field-components/specific-field/title/themed-item-page-field.component';
import { ItemPageUriFieldComponent } from '../../../../../../../app/item-page/simple/field-components/specific-field/uri/item-page-uri-field.component';
import { PublicationComponent as BaseComponent } from '../../../../../../../app/item-page/simple/item-types/publication/publication.component';
import { ThemedMetadataRepresentationListComponent } from '../../../../../../../app/item-page/simple/metadata-representation-list/themed-metadata-representation-list.component';
import { RelatedItemsComponent } from '../../../../../../../app/item-page/simple/related-items/related-items-component';
import { DsoEditMenuComponent } from '../../../../../../../app/shared/dso-page/dso-edit-menu/dso-edit-menu.component';
import { MetadataFieldWrapperComponent } from '../../../../../../../app/shared/metadata-field-wrapper/metadata-field-wrapper.component';
import { listableObjectComponent } from '../../../../../../../app/shared/object-collection/shared/listable-object/listable-object.decorator';
import { ThemedResultsBackButtonComponent } from '../../../../../../../app/shared/results-back-button/themed-results-back-button.component';
import { ThemedThumbnailComponent } from '../../../../../../../app/thumbnail/themed-thumbnail.component';
import { ItemPageDescriptionFieldComponent } from '../../field-components/specific-field/description/item-page-description.component';
import { ItemPageExternalPublicationFieldComponent } from '../../field-components/specific-field/external/item-page-external-publication.component';
import { TabbedRelatedEntitiesSearchComponent } from 'src/app/item-page/simple/related-entities/tabbed-related-entities-search/tabbed-related-entities-search.component';

/**
 * Component that represents a Study Item page
 */

@listableObjectComponent('Study',
  ViewMode.StandalonePage, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-publication',
  styleUrls: [
    '../../../../../../../app/item-page/simple/item-types/publication/publication.component.scss',
    './study.component.scss',
  ],
  templateUrl: './study.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: true,
  imports: [ItemPageExternalPublicationFieldComponent,
    ItemPageDescriptionFieldComponent, NgIf,
    NgFor,
    KeyValuePipe,
    NgbNavModule,
    ItemHeroBannerComponent,
    TabbedRelatedEntitiesSearchComponent,
    ThemedBadgesComponent,
    ThemedResultsBackButtonComponent,
    CommonModule,
    MiradorViewerComponent,
    ThemedItemPageTitleFieldComponent,
    DsoEditMenuComponent,
    MetadataFieldWrapperComponent,
    ThemedThumbnailComponent,
    ThemedMediaViewerComponent,
    ThemedFileSectionComponent,
    ItemPageDateFieldComponent,
    ThemedMetadataRepresentationListComponent,
    GenericItemPageFieldComponent,
    RelatedItemsComponent,
    ItemPageAbstractFieldComponent,
    ItemPageUriFieldComponent,
    CollectionsComponent,
    RouterLink,
    AsyncPipe,
    TranslateModule,
    ItemPageCcLicenseFieldComponent,
    ItemPageCitationFieldComponent,
    ItemPageFunderFieldComponent],
})
export class StudyComponent extends BaseComponent implements OnInit {

  /**
   * Currently active tab in the main study tab interface.
   * Valid IDs: 'overview' | 'analytics' | 'metadata'
   */
  activeTab: 'overview' | 'analytics' | 'metadata' = 'overview';

  /**
   * Emits `true` when the item has at least one downloadable bitstream in the
   * ORIGINAL bundle, `false` otherwise. Used to render a fallback message in
   * the Files section when no downloads are available.
   */
  hasFiles$: Observable<boolean> = new BehaviorSubject<boolean>(true).asObservable();

  private bitstreamDataService = inject(BitstreamDataService);

  ngOnInit(): void {
    super.ngOnInit();
    this.hasFiles$ = this.bitstreamDataService
      .findAllByItemAndBundleName(this.object, 'ORIGINAL', { elementsPerPage: 1, currentPage: 1 })
      .pipe(
        getFirstCompletedRemoteData(),
        map((rd) => rd?.hasSucceeded && (rd.payload?.totalElements ?? 0) > 0),
      );
  }

}
