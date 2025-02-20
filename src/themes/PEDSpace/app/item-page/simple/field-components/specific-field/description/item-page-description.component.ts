import { AsyncPipe } from '@angular/common';
import {
  Component,
  Input,
  OnInit,
} from '@angular/core';
import { Item } from 'src/app/core/shared/item.model';
import { MetadataValuesComponent } from 'src/app/item-page/field-components/metadata-values/metadata-values.component';
import { ItemPageFieldComponent } from 'src/app/item-page/simple/field-components/specific-field/item-page-field.component';

interface ProcessedMetadata {
  label: string;
  value: string;
}

@Component({
  selector: 'ds-item-page-description-field',
  templateUrl: '../../../../../../../../app/item-page/simple/field-components/specific-field/item-page-field.component.html',
  standalone: true,
  imports: [
    MetadataValuesComponent,
    AsyncPipe,
  ],
})
/**
 * This component is used for displaying the abstract (dc.description.abstract) of an item
 */
export class ItemPageDescriptionFieldComponent extends ItemPageFieldComponent implements OnInit {

  /**
   * The item to display metadata for
   */
  @Input() item: Item;

  /**
   * Separator string between multiple values of the metadata fields defined
   */
  separator: string;

  /**
   * Fields (schema.element.qualifier) used to render their values.
   * In this component, we want to display values for metadata 'dc.description'
   */
  fields: string[] = [
    'dc.description',
  ];

  /**
   * Label i18n key for the rendered metadata
   */
  @Input() label = 'item.page.description';

  /**
   * Use the {@link MarkdownDirective} to render dc.description values
   */
  enableMarkdown = true;

  /**
   * Array to hold the processed metadata for display
   */
  displayDescriptions: ProcessedMetadata[] = [];

  /**
   * Number of descriptions to display
   */
  readonly MAX_DESCRIPTIONS = 2;

  ngOnInit(): void {
    this.processDescriptions();
  }

  /**
   * Processes the dc.description metadata to extract the first n values with appropriate labels
   */
  private processDescriptions(): void {
    if (this.item?.metadata['dc.description']) {
      this.displayDescriptions = this.item.metadata['dc.description']
        .slice(0, this.MAX_DESCRIPTIONS)
        .map((metadata, index) => ({
          label: this.getLabelForIndex(index),
          value: metadata.value,
        }));
    }
  }

  /**
   * Returns the appropriate label based on the index
   * @param index The index of the metadata item
   */
  private getLabelForIndex(index: number): string {
    const labels = [
      'item.page.description',
      'item.page.description.cohort',
      // Add more labels here if MAX_DESCRIPTIONS increases
    ];
    return labels[index] || 'item.page.description.additional'; // Fallback label
  }
}
