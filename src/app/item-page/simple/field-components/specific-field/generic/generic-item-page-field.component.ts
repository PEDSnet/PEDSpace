import { AsyncPipe } from '@angular/common';
import {
  Component,
  Input
} from '@angular/core';

import { Item } from '../../../../../core/shared/item.model';
import { MetadataValuesComponent } from '../../../../field-components/metadata-values/metadata-values.component';
import { ItemPageFieldComponent } from '../item-page-field.component';

@Component({
  selector: 'ds-generic-item-page-field',
  templateUrl: './generic-item-page-field.component.html',
  standalone: true,
  imports: [MetadataValuesComponent, AsyncPipe],
})
/**
 * This component can be used to represent metadata on a simple item page.
 * It is the most generic way of displaying metadata values
 * It expects 5 parameters: The item, a separator, the metadata keys, an i18n key, and a sentence template
 */
export class GenericItemPageFieldComponent extends ItemPageFieldComponent {

  /**
   * The item to display metadata for
   */
  @Input() item: Item;

  /**
   * Separator string between multiple values of the metadata fields defined
   * @type {string}
   */
  @Input() separator: string;

  /**
   * Fields (schema.element.qualifier) used to render their values.
   */
  @Input() fields: string[];

  /**
   * Label i18n key for the rendered metadata
   */
  @Input() label: string;

  /**
   * Whether the {@link MarkdownDirective} should be used to render this metadata.
   */
  @Input() enableMarkdown = false;

  /**
   * Whether any valid HTTP(S) URL should be rendered as a link
   */
  @Input() urlRegex?: string;

  /**
   * Whether the metadata value should be rendered as a button
   */
  @Input() renderAsButton = false;

  /**
   * The type of entity that the metadata is being displayed for
   */
  @Input() entityType: string;

  /**
   * Template string for inserting the metadata value into a sentence
   * Use [value] as a placeholder for the metadata value
   * @type {string}
   */
  @Input() sentenceTemplate?: string;

  /**
   * Flag to indicate if the DQ check requirement is enabled
   */
  @Input() isDQCheckRequirement = false;

  @Input() isDateRange = false;


  // In item-page-field.component.ts, add this method
  getCombinedMetadataValues() {
    if (!this.item || !this.fields || this.fields.length === 0) {
      return [];
    }

    if (this.fields.length === 1) {
      return this.item.allMetadata(this.fields);
    }

    const combinedValues = [];
    const valuesMap = {};

    this.fields.forEach(field => {
      const values = this.item.allMetadata([field]);
      if (values && values.length > 0) {
        valuesMap[field] = values;
      }
    });

    if (this.fields.length === 2) {
      const field1 = this.fields[0];
      const field2 = this.fields[1];

      if (valuesMap[field1] && valuesMap[field1].length > 0 &&
        valuesMap[field2] && valuesMap[field2].length > 0) {
        combinedValues.push({
          value: valuesMap[field1][0].value + this.separator + valuesMap[field2][0].value,
          language: valuesMap[field1][0].language,
          authority: null,
          place: -1
        });
      } else if (valuesMap[field1] && valuesMap[field1].length > 0) {
        combinedValues.push(valuesMap[field1][0]);
      } else if (valuesMap[field2] && valuesMap[field2].length > 0) {
        combinedValues.push(valuesMap[field2][0]);
      }
    }

    return combinedValues;
  }

}