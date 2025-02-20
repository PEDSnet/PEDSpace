import {
  NgClass,
  NgIf,
  NgStyle,
} from '@angular/common';
import {
  Component,
  Input,
  OnInit,
} from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { Item } from 'src/app/core/shared/item.model';
import { MetadataFieldWrapperComponent } from 'src/app/shared/metadata-field-wrapper/metadata-field-wrapper.component';

@Component({
  selector: 'ds-item-page-cc-license-field',
  templateUrl: './item-page-cc-license-field.component.html',
  standalone: true,
  imports: [NgIf, NgClass, NgStyle, TranslateModule, MetadataFieldWrapperComponent],
})
/**
 * Displays the item's Creative Commons or other licenses in its simple item page
 */
export class ItemPageCcLicenseFieldComponent implements OnInit {
  /**
   * The item to display the license information for
   */
  @Input() item: Item;

  /**
   * 'full' variant shows image, a disclaimer (optional) and name (always), better for the item page content.
   * 'small' variant shows image and name (optional), better for the item page sidebar
   */
  @Input() variant?: 'small' | 'full' = 'small';

  /**
   * Field name containing the license URI
   */
  @Input() licenseUriField = 'dc.rights.uri';

  /**
   * Field name containing the license name or text
   */
  @Input() licenseNameField = 'dc.rights';

  /**
   * Shows the license name with the image. Always show if image fails to load
   */
  @Input() showName = true;

  /**
   * Shows the disclaimer in the 'full' variant of the component
   */
  @Input() showDisclaimer = true;

  uri = '';
  name = '';
  showImage = true;
  imgSrc: string | null = null;
  badgeUrl: string | null = null;
  licenseType: 'cc' | 'osi' | 'other' = 'other';

  /**
   * Mapping of license names to their respective URIs
   */
  private licenseUriMap: { [key: string]: string } = {
    'MIT License': 'https://opensource.org/licenses/MIT',
    'Apache License 2.0': 'https://opensource.org/licenses/Apache-2.0',
    'GNU General Public License v3.0': 'https://www.gnu.org/licenses/gpl-3.0.en.html',
    'BSD 3-Clause "New" or "Revised" License': 'https://opensource.org/licenses/BSD-3-Clause',
    'Mozilla Public License 2.0': 'https://opensource.org/licenses/MPL-2.0',
    // Add more mappings as needed
  };

  /**
   * Mapping of license codes to their display colors (for Shields.io)
   */
  private licenseColorMap: { [key: string]: string } = {
    'MIT': 'yellow',
    'Apache-2.0': 'blue',
    'GPL-3.0': 'blue',
    'BSD-3-Clause': 'orange',
    'MPL-2.0': 'brightgreen',
    // Add more mappings as needed
  };

  ngOnInit() {
    this.uri = this.item.firstMetadataValue(this.licenseUriField) || '';
    this.name = this.item.firstMetadataValue(this.licenseNameField) || '';

    // If URI is not provided, attempt to infer it from the license name
    if (!this.uri && this.name && this.licenseUriMap[this.name]) {
      this.uri = this.licenseUriMap[this.name];
    }

    // Updated regex to handle both CC and OSI licenses
    const regex = /.*(?:creativecommons\.org\/(?:licenses|publicdomain)\/([^/]+)|opensource\.org\/licenses\/([^/]+))/i;
    const matches = regex.exec(this.uri) || [];

    const ccCode = matches[1] || matches[2] || null;

    if (ccCode) {
      this.licenseType = matches[1] ? 'cc' : 'osi';
      this.imgSrc = `assets/images/licenses/${ccCode}.png`;
    } else {
      this.licenseType = 'other';
      this.imgSrc = null; // Indicate that no specific image exists
    }

    if (!this.imgSrc && this.name) {
      this.badgeUrl = this.generateBadgeUrl(this.name);
    }

    console.log('License URI:', this.uri);
    console.log('License Name:', this.name);
    console.log('Image Source:', this.imgSrc);
    console.log('Badge URL:', this.badgeUrl);
  }

  /**
   * Generates a Shields.io badge URL based on the license name
   * @param licenseName The name of the license
   * @returns The URL to the generated badge
   */
  private generateBadgeUrl(licenseName: string): string {
    // Sanitize the license name for use in the badge
    const label = encodeURIComponent('License');
    const message = encodeURIComponent(licenseName);
    const color = this.getBadgeColor(licenseName);

    // Choose a style (optional: 'flat', 'plastic', 'for-the-badge', etc.)
    const style = 'flat';

    return `https://img.shields.io/badge/${label}-${message}-${color}.svg?style=${style}`;
  }

  /**
   * Determines the color of the badge based on the license name
   * @param licenseName The name of the license
   * @returns The color code or name for the badge
   */
  private getBadgeColor(licenseName: string): string {
    // Extract license code if possible (e.g., MIT from 'MIT License')
    const codeMatch = licenseName.match(/([A-Za-z0-9\-]+)\s*License/i);
    const code = codeMatch ? codeMatch[1] : licenseName;

    return this.licenseColorMap[code] || 'lightgrey'; // Default color if not found
  }
}
