import {
  AsyncPipe,
  NgClass,
  NgIf,
} from '@angular/common';
import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';

import { ProjectSearchResultListElementComponent as BaseComponent } from '../../../../../../../../app/entity-groups/research-entities/item-list-elements/search-result-list-elements/project/project-search-result-list-element.component';
import { Context } from '../../../../../../../../app/core/shared/context.model';
import { ViewMode } from '../../../../../../../../app/core/shared/view-mode.model';
import { ThemedBadgesComponent } from '../../../../../../../../app/shared/object-collection/shared/badges/themed-badges.component';
import { listableObjectComponent } from '../../../../../../../../app/shared/object-collection/shared/listable-object/listable-object.decorator';
import { TruncatableComponent } from '../../../../../../../../app/shared/truncatable/truncatable.component';
import { ThemedThumbnailComponent } from '../../../../../../../../app/thumbnail/themed-thumbnail.component';

@listableObjectComponent('ProjectSearchResult', ViewMode.ListElement, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-project-search-result-list-element',
  styleUrls: ['./project-search-result-list-element.component.scss'],
  templateUrl: './project-search-result-list-element.component.html',
  standalone: true,
  imports: [NgIf, RouterLink, ThemedThumbnailComponent, NgClass, TruncatableComponent, ThemedBadgesComponent, AsyncPipe],
})
export class ProjectSearchResultListElementComponent extends BaseComponent {
}
