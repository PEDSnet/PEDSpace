import {
  AsyncPipe,
  NgClass,
  NgIf,
} from '@angular/common';
import {
  Component,
  Input,
  OnInit,
} from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { Item } from 'src/app/core/shared/item.model';
import { MetadataFieldWrapperComponent } from 'src/app/shared/metadata-field-wrapper/metadata-field-wrapper.component';

/**
 * Component that displays a formatted citation for an item using APA style
 */
@Component({
  selector: 'ds-item-page-citation-field',
  templateUrl: './item-page-citation-field.component.html',
  styleUrls: ['./item-page-citation-field.component.scss'],
  standalone: true,
  imports: [
    NgIf,
    AsyncPipe,
    TranslateModule,
    MetadataFieldWrapperComponent,
    NgClass,
  ],
})
export class ItemPageCitationFieldComponent implements OnInit {
  /**
   * The item to display the citation for
   */
  @Input() item: Item;

  /**
   * The label to display (optional)
   */
  @Input() label = 'Citation';

  /**
   * The generated citation text
   */
  citation: string;

  /**
   * Whether the citation was copied
   */
  isCopied = false;

  ngOnInit(): void {
    this.generateCitation();
  }

  /**
   * Generate APA-style citation from item metadata
   */
  generateCitation(): void {
    if (!this.item) {
      return;
    }

    const metadata = this.item.metadata;

    // Extract author/creator
    const authors = this.getAuthors(metadata);

    // Extract date
    const date = this.getDate(metadata);

    // Extract title
    const title = this.getTitle(metadata);

    // Extract entity type
    const entityType = this.getEntityType(metadata);

    // Extract handle/URI
    const handle = this.getHandle(metadata);

    // Construct APA citation
    // Format: Author(s). (Year, Month). Title. [Type]. Site Name. Handle
    const parts: string[] = [];

    if (authors) {
      parts.push(authors);
    }

    if (date) {
      parts.push(`(${date}).`);
    }

    if (title) {
      parts.push(`${title}.`);
    }

    if (entityType) {
      parts.push(`[${entityType}].`);
    }

    parts.push('PEDSpace Knowledge Bank.');

    if (handle) {
      parts.push(handle);
    }

    this.citation = parts.join(' ');
  }

  /**
   * Extract and format authors from metadata
   */
  private getAuthors(metadata: any): string {
    // Try dc.contributor.author first, then dc.creator
    const authorFields = metadata['dc.contributor.author'] || metadata['dc.creator'] || [];

    if (authorFields.length === 0) {
      return '';
    }

    // For multiple authors, format as: LastName1, F., LastName2, F., & LastName3, F.
    const formattedAuthors = authorFields.map((author: any) => {
      const name = author.value;
      return this.formatAuthorName(name);
    });

    if (formattedAuthors.length === 1) {
      return formattedAuthors[0] + '.';
    } else if (formattedAuthors.length === 2) {
      return formattedAuthors.join(' & ') + '.';
    } else {
      const lastAuthor = formattedAuthors.pop();
      return formattedAuthors.join(', ') + ', & ' + lastAuthor + '.';
    }
  }

  /**
   * Format author name to APA style (LastName, F.)
   */
  private formatAuthorName(fullName: string): string {
    // Handle "LastName, FirstName" or "FirstName LastName" formats
    const parts = fullName.split(',').map(p => p.trim());

    if (parts.length === 2) {
      // Already in "LastName, FirstName" format
      const lastName = parts[0];
      const firstName = parts[1];
      const initial = firstName.charAt(0).toUpperCase();
      return `${lastName}, ${initial}.`;
    } else {
      // Assume "FirstName LastName" format
      const nameParts = fullName.trim().split(' ');
      if (nameParts.length === 1) {
        return nameParts[0];
      }
      const lastName = nameParts[nameParts.length - 1];
      const firstName = nameParts[0];
      const initial = firstName.charAt(0).toUpperCase();
      return `${lastName}, ${initial}.`;
    }
  }

  /**
   * Extract and format date from metadata
   */
  private getDate(metadata: any): string {
    // Try dc.date.issued first, then dc.date.created, then dc.date
    const dateField = metadata['dc.date.issued']?.[0] ||
                      metadata['dc.date.created']?.[0] ||
                      metadata['dc.date']?.[0];

    if (!dateField) {
      return '';
    }

    const dateValue = dateField.value;

    // Parse date (assuming ISO format like "2024-01-15" or "2024")
    const date = new Date(dateValue);

    if (isNaN(date.getTime())) {
      // If not a valid date, just return the year if it's a 4-digit number
      const yearMatch = dateValue.match(/\d{4}/);
      return yearMatch ? yearMatch[0] : '';
    }

    const year = date.getFullYear();
    const month = date.toLocaleString('en-US', { month: 'long' });

    return `${year}, ${month}`;
  }

  /**
   * Extract title from metadata
   */
  private getTitle(metadata: any): string {
    const titleField = metadata['dc.title']?.[0];
    return titleField ? titleField.value : 'Untitled';
  }

  /**
   * Extract entity type from metadata
   */
  private getEntityType(metadata: any): string {
    // Try to get the entity type from dspace.entity.type
    const entityTypeField = metadata['dspace.entity.type']?.[0];

    if (entityTypeField) {
      // Convert CamelCase to Title Case with spaces
      const entityType = entityTypeField.value;
      return entityType.replace(/([A-Z])/g, ' $1').trim();
    }

    // Fallback to dc.type
    const typeField = metadata['dc.type']?.[0];
    return typeField ? typeField.value : 'Item';
  }

  /**
   * Extract handle/URI from metadata (prioritize DOI over handle)
   */
  private getHandle(metadata: any): string {
    const uriFields = metadata['dc.identifier.uri'] || [];

    // Prefer DOI first
    const doiUri = uriFields.find((uri: any) => uri.value.includes('doi.org'));
    if (doiUri) {
      return doiUri.value;
    }

    // Fallback to handle.net URLs
    const handleUri = uriFields.find((uri: any) => uri.value.includes('hdl.handle.net'));
    if (handleUri) {
      return handleUri.value;
    }

    // Return first URI if available
    return uriFields[0]?.value || '';
  }

  /**
   * Copy citation to clipboard
   */
  async copyCitation(): Promise<void> {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(this.citation);
        this.showCopySuccess();
      } else {
        this.fallbackCopyToClipboard(this.citation);
      }
    } catch (error) {
      console.error('Failed to copy citation:', error);
    }
  }

  /**
   * Fallback copy method for older browsers
   */
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
      this.showCopySuccess();
    } catch (error) {
      console.error('Fallback copy failed:', error);
    } finally {
      document.body.removeChild(textArea);
    }
  }

  /**
   * Show success feedback for copy operation
   */
  private showCopySuccess(): void {
    this.isCopied = true;

    setTimeout(() => {
      this.isCopied = false;
    }, 3000);
  }
}
