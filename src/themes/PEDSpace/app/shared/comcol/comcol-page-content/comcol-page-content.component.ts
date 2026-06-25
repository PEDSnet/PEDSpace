import { NgIf } from '@angular/common';
import { Component, inject } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import { ComcolPageContentComponent as BaseComponent } from '../../../../../../app/shared/comcol/comcol-page-content/comcol-page-content.component';
import { BrowseSubdomainsComponent } from './browse-subdomains/browse-subdomains.component';

@Component({
  selector: 'ds-themed-comcol-page-content',
  styleUrls: [
    './comcol-page-content.component.scss',
    '../../../../../../app/shared/comcol/comcol-page-content/comcol-page-content.component.scss',
  ],
  templateUrl: './comcol-page-content.component.html',
  imports: [
    TranslateModule,
    NgIf,
    BrowseSubdomainsComponent,
  ],
  standalone: true,
})
export class ComcolPageContentComponent extends BaseComponent {

  private router = inject(Router);

  get showBrowseSubdomains(): boolean {
    return this.router.url.startsWith('/communities');
  }

  get displayContent(): string {
    return this.content;
  }

}
