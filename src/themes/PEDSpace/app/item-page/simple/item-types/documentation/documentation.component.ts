import {
  AsyncPipe,
  CommonModule,
  NgIf,
} from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  OnInit,
} from '@angular/core';
import {
  Router,
  RouterLink,
} from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { NgxExtendedPdfViewerModule } from 'ngx-extended-pdf-viewer';
import { Observable } from 'rxjs';
import {
  filter,
  map,
  switchMap,
} from 'rxjs/operators';
import { TabbedRelatedEntitiesSearchComponent } from 'src/app/item-page/simple/related-entities/tabbed-related-entities-search/tabbed-related-entities-search.component';
// import copy from 'copy-to-clipboard';
import { ThemedBadgesComponent } from 'src/app/shared/object-collection/shared/badges/themed-badges.component';

import { BitstreamDataService } from '../../../../../../../app/core/data/bitstream-data.service';
import { PaginatedList } from '../../../../../../../app/core/data/paginated-list.model';
import { RemoteData } from '../../../../../../../app/core/data/remote-data';
import { RouteService } from '../../../../../../../app/core/services/route.service';
import { FileService } from '../../../../../../../app/core/shared/file.service';
import { Bitstream } from '../../../../../../../app/core/shared/bitstream.model';
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

/**
 * Component that represents a Documentation Item page
 */

@listableObjectComponent('Documentation',
  ViewMode.StandalonePage, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-publication',
  styleUrls: ['./documentation.component.scss'],
  // styleUrls: ['../../../../../../../app/item-page/simple/item-types/publication/publication.component.scss'],
  templateUrl: './documentation.component.html',
  // templateUrl: '../../../../../../../app/item-page/simple/item-types/publication/publication.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: true,
  imports: [ItemPageExternalPublicationFieldComponent,
    ItemPageDescriptionFieldComponent, NgIf,
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
    TabbedRelatedEntitiesSearchComponent,
    NgxExtendedPdfViewerModule],
})
export class DocumentationComponent extends BaseComponent implements OnInit {
  pdfSrc$: Observable<string | null>;
  showPdfModal = false;

  constructor(
    protected override routeService: RouteService,
    protected override router: Router,
    private bitstreamDataService: BitstreamDataService,
    private fileService: FileService,
  ) {
    super(routeService, router);
  }

  override ngOnInit(): void {
    super.ngOnInit();

    // Get the first PDF file from the item's bitstreams
    this.pdfSrc$ = this.bitstreamDataService.findAllByItemAndBundleName(
      this.object,
      'ORIGINAL',
      { elementsPerPage: 100 },
    ).pipe(
      map((bitstreamsRD: RemoteData<PaginatedList<Bitstream>>) => {
        if (bitstreamsRD?.hasSucceeded && bitstreamsRD?.payload?.page) {
          // Find the first PDF file
          const pdfBitstream = bitstreamsRD.payload.page.find(
            (bitstream: Bitstream) =>
              bitstream.name?.toLowerCase().endsWith('.pdf'),
          );

          if (pdfBitstream?._links?.content?.href) {
            return pdfBitstream._links.content.href;
          }
        }
        
        return null;
      }),
      switchMap((pdfUrl: string | null) => {
        if (!pdfUrl) {
          return [null];
        }
        
        // Get authenticated download link with short-lived token
        return this.fileService.retrieveFileDownloadLink(pdfUrl);
      }),
    );
  }

  openPdfModal(): void {
    this.showPdfModal = true;
  }

  closePdfModal(): void {
    this.showPdfModal = false;
  }
}
