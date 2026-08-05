import {
  AsyncPipe,
  NgIf,
} from '@angular/common';
import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';

import { BrowseByTitleComponent as BaseComponent } from '../../../../../app/browse-by/browse-by-title/browse-by-title.component';
import { ThemedBreadcrumbsComponent } from '../../../../../app/breadcrumbs/themed-breadcrumbs.component';
import { ThemedBrowseByComponent } from '../../../../../app/shared/browse-by/themed-browse-by.component';
import { ComcolPageHeaderComponent } from '../../../../../app/shared/comcol/comcol-page-header/comcol-page-header.component';
import { ThemedLoadingComponent } from '../../../../../app/shared/loading/themed-loading.component';

@Component({
  selector: 'ds-browse-by-title',
  // styleUrls: ['./browse-by-title.component.scss'],
  styleUrls: ['../../../../../app/browse-by/browse-by-metadata/browse-by-metadata.component.scss'],
  // templateUrl: './browse-by-title.component.html',
  templateUrl: '../../../../../app/browse-by/browse-by-metadata/browse-by-metadata.component.html',
  standalone: true,
  imports: [
    AsyncPipe,
    NgIf,
    ComcolPageHeaderComponent,
    TranslateModule,
    ThemedBreadcrumbsComponent,
    ThemedLoadingComponent,
    ThemedBrowseByComponent,
  ],
})
export class BrowseByTitleComponent extends BaseComponent {
}
