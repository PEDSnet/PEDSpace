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

   /** Transient copied-confirmation flag for the Cite button. */
  citeCopied = signal(false);

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

  /**
   * Builds an APA-style citation string from the item's metadata.
   */
  get citation(): string {
    if (!this.item) {
      return '';
    }

    const metadata = this.item.metadata;
    const parts: string[] = [];

    const authors = this.getAuthors(metadata);
    if (authors) { parts.push(authors); }

    const date = this.getDate(metadata);
    if (date) { parts.push(`(${date}).`); }

    const title = this.getTitle(metadata);
    if (title) { parts.push(`${title}.`); }

    const entityType = this.getCitationEntityType(metadata);
    if (entityType) { parts.push(`[${entityType}].`); }

    parts.push('PEDSpace Knowledge Bank.');

    const handle = this.getHandle(metadata);
    if (handle) { parts.push(handle); }

    return parts.join(' ');
  }

  async copyCitation(): Promise<void> {
    const text = this.citation;
    if (!text) { return; }
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
      } else {
        this.fallbackCopyToClipboard(text);
      }
      this.citeCopied.set(true);
      setTimeout(() => this.citeCopied.set(false), 2000);
    } catch (error) {
      console.error('Failed to copy citation:', error);
    }
  }

  private fallbackCopyToClipboard(text: string): void {
    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-999999px';
    textArea.style.top = '-999999px';
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    try {
      document.execCommand('copy');
    } catch (error) {
      console.error('Fallback copy failed:', error);
    } finally {
      document.body.removeChild(textArea);
    }
  }

  private getAuthors(metadata: any): string {
    const authorFields = metadata['dc.contributor.author'] || metadata['dc.creator'] || [];
    if (authorFields.length === 0) { return ''; }

    const formattedAuthors = authorFields.map((author: any) => this.formatAuthorName(author.value));

    if (formattedAuthors.length === 1) {
      return formattedAuthors[0];
    } else if (formattedAuthors.length === 2) {
      return formattedAuthors.join(' & ');
    } else {
      const lastAuthor = formattedAuthors.pop();
      return formattedAuthors.join(', ') + ', & ' + lastAuthor;
    }
  }

  private formatAuthorName(fullName: string): string {
    const parts = fullName.split(',').map(p => p.trim());

    if (parts.length === 2) {
      const lastName = parts[0];
      const firstName = parts[1];
      const initial = firstName.charAt(0).toUpperCase();
      return `${lastName}, ${initial}.`;
    } else {
      const nameParts = fullName.trim().split(' ');

      if (nameParts.length === 1) {
        return nameParts[0] + '.';
      }

      const orgKeywords = ['center', 'centre', 'committee', 'organization', 'organisation',
        'institute', 'foundation', 'association', 'department', 'group',
        'team', 'network', 'consortium', 'society', 'council'];
      const lowerName = fullName.toLowerCase();
      const isOrganization = orgKeywords.some(keyword => lowerName.includes(keyword));

      if (isOrganization) {
        return fullName + '.';
      }

      const lastName = nameParts[nameParts.length - 1];
      const firstName = nameParts[0];
      const initial = firstName.charAt(0).toUpperCase();
      return `${lastName}, ${initial}.`;
    }
  }

  private getDate(metadata: any): string {
    const dateField = metadata['dc.date.issued']?.[0] ||
      metadata['dc.date.created']?.[0] ||
      metadata['dc.date']?.[0];

    if (!dateField) { return ''; }

    const dateValue = dateField.value;
    const date = new Date(dateValue);

    if (isNaN(date.getTime())) {
      const yearMatch = dateValue.match(/\d{4}/);
      return yearMatch ? yearMatch[0] : '';
    }

    const year = date.getFullYear();
    const month = date.toLocaleString('en-US', { month: 'long' });
    return `${year}, ${month}`;
  }

  private getTitle(metadata: any): string {
    const titleField = metadata['dc.title']?.[0];
    return titleField ? titleField.value : 'Untitled';
  }

  private getCitationEntityType(metadata: any): string {
    const entityTypeField = metadata['dspace.entity.type']?.[0];
    if (entityTypeField) {
      return entityTypeField.value.replace(/([A-Z])/g, ' $1').trim();
    }
    const typeField = metadata['dc.type']?.[0];
    return typeField ? typeField.value : 'Item';
  }

  private getHandle(metadata: any): string {
    const uriFields = metadata['dc.identifier.uri'] || [];
    const doiUri = uriFields.find((uri: any) => uri.value.includes('doi.org'));
    if (doiUri) { return doiUri.value; }
    const handleUri = uriFields.find((uri: any) => uri.value.includes('hdl.handle.net'));
    if (handleUri) { return handleUri.value; }
    return uriFields[0]?.value || '';
  }
}

