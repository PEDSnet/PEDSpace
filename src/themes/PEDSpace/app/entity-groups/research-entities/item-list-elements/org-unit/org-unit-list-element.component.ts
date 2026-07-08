import { Component } from '@angular/core';

import { Item } from '../../../../../../../app/core/shared/item.model';
import { Context } from '../../../../../../../app/core/shared/context.model';
import { ViewMode } from '../../../../../../../app/core/shared/view-mode.model';
import { listableObjectComponent } from '../../../../../../../app/shared/object-collection/shared/listable-object/listable-object.decorator';
import { AbstractListableElementComponent } from '../../../../../../../app/shared/object-collection/shared/object-collection-element/abstract-listable-element.component';
import { OrgUnitSearchResultListElementComponent } from '../search-result-list-elements/org-unit/org-unit-search-result-list-element.component';

@listableObjectComponent('OrgUnit', ViewMode.ListElement, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-org-unit-list-element',
  template: `<ds-org-unit-search-result-list-element [object]="{ indexableObject: object, hitHighlights: {} }"
                                                     [linkType]="linkType"
                                                     [showLabel]="showLabel"
                                                     [value]="value">
             </ds-org-unit-search-result-list-element>`,
  standalone: true,
  imports: [OrgUnitSearchResultListElementComponent],
})
export class OrgUnitListElementComponent extends AbstractListableElementComponent<Item> {
}
