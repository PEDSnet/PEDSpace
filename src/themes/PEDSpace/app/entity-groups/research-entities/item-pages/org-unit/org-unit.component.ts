import {
  AsyncPipe,
  NgIf,
  KeyValuePipe,
  NgForOf
} from '@angular/common';
import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { NgbAccordionModule } from '@ng-bootstrap/ng-bootstrap';
import { ViewMode } from 'src/app/core/shared/view-mode.model';
import { GenericItemPageFieldComponent } from 'src/app/item-page/simple/field-components/specific-field/generic/generic-item-page-field.component';
import { ItemPageImgFieldComponent } from 'src/app/item-page/simple/field-components/specific-field/img/item-page-img-field.component';
import { ThemedItemPageTitleFieldComponent } from 'src/app/item-page/simple/field-components/specific-field/title/themed-item-page-field.component';
// import { ItemComponent } from 'src/app/item-page/simple/item-types/shared/item.component';
import { TabbedRelatedEntitiesSearchComponent } from 'src/app/item-page/simple/related-entities/tabbed-related-entities-search/tabbed-related-entities-search.component';
import { RelatedItemsComponent } from 'src/app/item-page/simple/related-items/related-items-component';
import { DsoEditMenuComponent } from 'src/app/shared/dso-page/dso-edit-menu/dso-edit-menu.component';
import { MetadataFieldWrapperComponent } from 'src/app/shared/metadata-field-wrapper/metadata-field-wrapper.component';
import { listableObjectComponent } from 'src/app/shared/object-collection/shared/listable-object/listable-object.decorator';
import { ThemedResultsBackButtonComponent } from 'src/app/shared/results-back-button/themed-results-back-button.component';
import { ThemedThumbnailComponent } from 'src/app/thumbnail/themed-thumbnail.component';
import { Context } from '../../../../../../../app/core/shared/context.model';
import { OrgUnitComponent as BaseComponent } from 'src/app/entity-groups/research-entities/item-pages/org-unit/org-unit.component';
import { ItemPageLocalFieldComponent } from 'src/themes/PEDSpace/app/item-page/simple/field-components/specific-field/local/item-page-local.component';
import { ItemPageAbstractFieldComponent } from 'src/app/item-page/simple/field-components/specific-field/abstract/item-page-abstract-field.component';
// import { BadgesComponent } from 'src/themes/PEDSpace/app/shared/object-collection/shared/badges/badges.component';
import { ThemedBadgesComponent } from 'src/app/shared/object-collection/shared/badges/themed-badges.component';

@listableObjectComponent('OrgUnit', ViewMode.StandalonePage, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-org-unit',
  styleUrls: ['./org-unit.component.scss'],
  // styleUrls: ['../../../../../../../app/entity-groups/research-entities/item-pages/person/person.component.scss'],
  templateUrl: './org-unit.component.html',
  // templateUrl: '../../../../../../../app/entity-groups/research-entities/item-pages/person/person.component.html',
  standalone: true,
  imports: [NgIf, ThemedResultsBackButtonComponent, ThemedItemPageTitleFieldComponent, DsoEditMenuComponent, MetadataFieldWrapperComponent, ThemedThumbnailComponent, GenericItemPageFieldComponent, RelatedItemsComponent, RouterLink, TabbedRelatedEntitiesSearchComponent, AsyncPipe, TranslateModule, ItemPageImgFieldComponent, ItemPageLocalFieldComponent, KeyValuePipe, NgForOf, ItemPageAbstractFieldComponent, ThemedBadgesComponent, NgbAccordionModule],
})
export class OrgUnitComponent extends BaseComponent {
}
