import { Component } from '@angular/core';

import { Item } from '../../../../../../../app/core/shared/item.model';
import { Context } from '../../../../../../../app/core/shared/context.model';
import { ViewMode } from '../../../../../../../app/core/shared/view-mode.model';
import { listableObjectComponent } from '../../../../../../../app/shared/object-collection/shared/listable-object/listable-object.decorator';
import { AbstractListableElementComponent } from '../../../../../../../app/shared/object-collection/shared/object-collection-element/abstract-listable-element.component';
import { PersonSearchResultListElementComponent } from '../search-result-list-elements/person/person-search-result-list-element.component';

@listableObjectComponent('Person', ViewMode.ListElement, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-person-list-element',
  template: `<ds-person-search-result-list-element [object]="{ indexableObject: object, hitHighlights: {} }"
                                                   [linkType]="linkType"
                                                   [showLabel]="showLabel"
                                                   [value]="value">
             </ds-person-search-result-list-element>`,
  standalone: true,
  imports: [PersonSearchResultListElementComponent],
})
export class PersonListElementComponent extends AbstractListableElementComponent<Item> {
}
