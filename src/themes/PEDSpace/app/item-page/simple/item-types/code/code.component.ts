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
import {
  select,
  Store,
} from '@ngrx/store';
import { TranslateModule } from '@ngx-translate/core';
import { Observable } from 'rxjs';
import { ThemedBadgesComponent } from 'src/app/shared/object-collection/shared/badges/themed-badges.component';

import { AppState } from '../../../../../../../app/app.reducer';
import { isAuthenticated } from '../../../../../../../app/core/auth/selectors';
import { RouteService } from '../../../../../../../app/core/services/route.service';
import { Context } from '../../../../../../../app/core/shared/context.model';
import { ViewMode } from '../../../../../../../app/core/shared/view-mode.model';
import { CollectionsComponent } from '../../../../../../../app/item-page/field-components/collections/collections.component';
import { ThemedMediaViewerComponent } from '../../../../../../../app/item-page/media-viewer/themed-media-viewer.component';
import { MiradorViewerComponent } from '../../../../../../../app/item-page/mirador-viewer/mirador-viewer.component';
import { ThemedFileSectionComponent } from '../../../../../../../app/item-page/simple/field-components/file-section/themed-file-section.component';
import { ItemPageAbstractFieldComponent } from '../../../../../../../app/item-page/simple/field-components/specific-field/abstract/item-page-abstract-field.component';
// import { Item } from '../../../../../../../app/core/shared/item.model';
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
import { ItemPageLocalFieldComponent } from '../../field-components/specific-field/local/item-page-local.component';

/**
 * Component that represents a Code Item page
 */

@listableObjectComponent('Code',
  ViewMode.StandalonePage, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-publication',
  // styleUrls: ['./publication.component.scss'],
  styleUrls: ['./code.component.scss'],
  templateUrl: './code.component.html',
  // templateUrl: '../../../../../../../app/item-page/simple/item-types/publication/publication.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: true,
  imports: [ItemPageExternalPublicationFieldComponent,
    ItemPageExternalPublicationFieldComponent,
    ItemPageDescriptionFieldComponent, NgIf,
    ThemedResultsBackButtonComponent,
    CommonModule,
    ItemPageLocalFieldComponent,
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
    ThemedBadgesComponent],
})
export class CodeComponent extends BaseComponent implements OnInit {

  /**
   * Whether the current user is authenticated
   */
  public isAuthenticated$: Observable<boolean>;

  constructor(
    protected routeService: RouteService,
    protected router: Router,
    private store: Store<AppState>,
  ) {
    super(routeService, router);
  }

  ngOnInit(): void {
    super.ngOnInit();
    // set isAuthenticated
    this.isAuthenticated$ = this.store.pipe(select(isAuthenticated));
  }

}
