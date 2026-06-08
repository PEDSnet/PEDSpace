import {
  CommonModule,
  NgIf,
} from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  Input,
  signal,
} from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import { Item } from 'src/app/core/shared/item.model';

import { DsoEditMenuComponent } from 'src/app/shared/dso-page/dso-edit-menu/dso-edit-menu.component';
import { ThemedItemPageTitleFieldComponent } from 'src/app/item-page/simple/field-components/specific-field/title/themed-item-page-field.component';

/**
 * Shared mint hero banner used on every PEDSpace item SIV page.
 *
 * Displays:
 *  - The item's `dspace.entity.type` as a clickable badge that links to
 *    the search page filtered by that entity type.
 *  - The item's title.
 *  - The DSO edit menu (right-aligned).
 */
@Component({
  selector: 'ds-pedspace-item-hero-banner',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './item-hero-banner.component.html',
  styleUrls: ['./item-hero-banner.component.scss'],
  imports: [
    CommonModule,
    NgIf,
    RouterLink,
    TranslateModule,
    DsoEditMenuComponent,
    ThemedItemPageTitleFieldComponent,
  ],
})
export class ItemHeroBannerComponent {
  /**
   * The current item.
   */
  @Input() item: Item;

  /**
   * Whether to render the DSO edit menu on the right side of the banner.
   */
  @Input() showEditMenu = true;

  /** Transient copied-confirmation flag. */
  copied = signal(false);

  /** Returns the best available persistent identifier URL (DOI preferred, then handle). */
  get shareUrl(): string | null {
    const doi = this.item?.firstMetadataValue('dc.identifier.doi');
    if (doi) {
      return doi.startsWith('http') ? doi : `https://doi.org/${doi}`;
    }
    const uri = this.item?.firstMetadataValue('dc.identifier.uri');
    return uri ?? null;
  }

  copyShareUrl(): void {
    const url = this.shareUrl;
    if (!url) { return; }
    navigator.clipboard.writeText(url).then(() => {
      this.copied.set(true);
      setTimeout(() => this.copied.set(false), 2000);
    });
  }

  /**
   * The current entity type derived from the item metadata.
   * Falls back to `'ITEM'` when no entity type is present.
   */
  get entityType(): string {
    const fromMeta = this.item?.firstMetadataValue('dspace.entity.type');
    return (fromMeta && fromMeta.trim().length > 0) ? fromMeta : 'ITEM';
  }

  /**
   * The router query params used to navigate to the search page filtered
   * by this entity type when the badge is clicked.
   */
  get badgeQueryParams(): Record<string, string> {
    return {
      'f.entityType': `${this.entityType},equals`,
      configuration: 'default',
    };
  }
}
