import { Component } from '@angular/core';
import {
  AsyncPipe,
  NgIf,
} from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import { Context } from '../../../../../../../../app/core/shared/context.model';
import { ViewMode } from '../../../../../../../../app/core/shared/view-mode.model';
import { focusShadow } from '../../../../../../../../app/shared/animations/focus';
import { ThemedBadgesComponent } from '../../../../../../../../app/shared/object-collection/shared/badges/themed-badges.component';
import { listableObjectComponent } from '../../../../../../../../app/shared/object-collection/shared/listable-object/listable-object.decorator';
import { TruncatableComponent } from '../../../../../../../../app/shared/truncatable/truncatable.component';
import { TruncatablePartComponent } from '../../../../../../../../app/shared/truncatable/truncatable-part/truncatable-part.component';
import { ProjectSearchResultGridElementComponent } from '../project/project-search-result-grid-element.component';

/**
 * PEDSpace-themed grid card for Study search results (#176).
 */
@listableObjectComponent('StudySearchResult', ViewMode.GridElement, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-pedspace-study-search-result-grid-element',
  styleUrls: ['../project/project-search-result-grid-element.component.scss'],
  templateUrl: '../project/project-search-result-grid-element.component.html',
  animations: [focusShadow],
  standalone: true,
  imports: [TruncatableComponent, NgIf, RouterLink, ThemedBadgesComponent, TruncatablePartComponent, AsyncPipe, TranslateModule],
})
export class StudySearchResultGridElementComponent extends ProjectSearchResultGridElementComponent {
}
