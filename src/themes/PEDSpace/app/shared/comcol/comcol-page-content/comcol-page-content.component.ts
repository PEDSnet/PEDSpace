import { NgIf } from '@angular/common';
import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';

import { ComcolPageContentComponent as BaseComponent } from '../../../../../../app/shared/comcol/comcol-page-content/comcol-page-content.component';
import { BrowseSubdomainsComponent } from './browse-subdomains/browse-subdomains.component';

/**
 * Token that, when present in the (innerHTML) content, triggers rendering of
 * the {@link BrowseSubdomainsComponent} dropdown. The token itself is stripped
 * from the displayed content.
 */
export const BROWSE_SUBDOMAINS_MARKER = '[[browse-subdomains]]';

@Component({
  selector: 'ds-themed-comcol-page-content',
  styleUrls: [
    './comcol-page-content.component.scss',
    '../../../../../../app/shared/comcol/comcol-page-content/comcol-page-content.component.scss',
  ],
  templateUrl: './comcol-page-content.component.html',
  // templateUrl: '../../../../../../app/shared/comcol/comcol-page-content/comcol-page-content.component.html',
  imports: [
    TranslateModule,
    NgIf,
    BrowseSubdomainsComponent,
  ],
  standalone: true,
})
export class ComcolPageContentComponent extends BaseComponent {

  /**
   * Whether the content requests the "Browse Subdomains" dropdown.
   */
  get showBrowseSubdomains(): boolean {
    return true; //this.hasInnerHtml && typeof this.content === 'string' && this.content.includes(BROWSE_SUBDOMAINS_MARKER);
  }

  /**
   * The content with the {@link BROWSE_SUBDOMAINS_MARKER} token removed, so the
   * raw token is never shown to the user.
   */
  get displayContent(): string {
    if (typeof this.content === 'string') {
      return this.content.split(BROWSE_SUBDOMAINS_MARKER).join('');
    }
    return this.content;
  }
}
