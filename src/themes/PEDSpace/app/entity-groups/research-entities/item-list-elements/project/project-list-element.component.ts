import { Component } from '@angular/core';

import { Item } from '../../../../../../../app/core/shared/item.model';
import { Context } from '../../../../../../../app/core/shared/context.model';
import { ViewMode } from '../../../../../../../app/core/shared/view-mode.model';
import { listableObjectComponent } from '../../../../../../../app/shared/object-collection/shared/listable-object/listable-object.decorator';
import { AbstractListableElementComponent } from '../../../../../../../app/shared/object-collection/shared/object-collection-element/abstract-listable-element.component';
import { ProjectSearchResultListElementComponent } from '../search-result-list-elements/project/project-search-result-list-element.component';

@listableObjectComponent('Project', ViewMode.ListElement, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-project-list-element',
  template: `<ds-project-search-result-list-element [object]="{ indexableObject: object, hitHighlights: {} }"
                                                    [linkType]="linkType"
                                                    [showLabel]="showLabel"
                                                    [value]="value">
             </ds-project-search-result-list-element>`,
  standalone: true,
  imports: [ProjectSearchResultListElementComponent],
})
export class ProjectListElementComponent extends AbstractListableElementComponent<Item> {
}
