import {
  AsyncPipe,
  NgClass,
  NgFor,
  NgIf,
} from '@angular/common';
import {
  Component,
  Inject,
  OnInit,
} from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import {
  APP_CONFIG,
  AppConfig,
} from '../../../../../../../../config/app-config.interface';
import { DSONameService } from '../../../../../../../../app/core/breadcrumbs/dso-name.service';
import { PersonSearchResultListElementComponent as BaseComponent } from '../../../../../../../../app/entity-groups/research-entities/item-list-elements/search-result-list-elements/person/person-search-result-list-element.component';
import { Context } from '../../../../../../../../app/core/shared/context.model';
import { ViewMode } from '../../../../../../../../app/core/shared/view-mode.model';
import { ThemedBadgesComponent } from '../../../../../../../../app/shared/object-collection/shared/badges/themed-badges.component';
import { listableObjectComponent } from '../../../../../../../../app/shared/object-collection/shared/listable-object/listable-object.decorator';
import { TruncatableComponent } from '../../../../../../../../app/shared/truncatable/truncatable.component';
import { TruncatableService } from '../../../../../../../../app/shared/truncatable/truncatable.service';
import { TruncatablePartComponent } from '../../../../../../../../app/shared/truncatable/truncatable-part/truncatable-part.component';
import { ThemedThumbnailComponent } from '../../../../../../../../app/thumbnail/themed-thumbnail.component';

@listableObjectComponent('PersonSearchResult', ViewMode.ListElement, Context.Any, 'PEDSpace')
@Component({
  selector: 'ds-person-search-result-list-element',
  styleUrls: ['./person-search-result-list-element.component.scss'],
  templateUrl: './person-search-result-list-element.component.html',
  standalone: true,
  imports: [NgIf, RouterLink, ThemedThumbnailComponent, NgClass, ThemedBadgesComponent, TruncatableComponent, TruncatablePartComponent, NgFor, AsyncPipe, TranslateModule],
})
export class PersonSearchResultListElementComponent extends BaseComponent {

  public constructor(
    protected truncatableService: TruncatableService,
    public dsoNameService: DSONameService,
    @Inject(APP_CONFIG) protected appConfig: AppConfig,
  ) {
    super(truncatableService, dsoNameService, appConfig);
  }
}
