import { AsyncPipe } from '@angular/common';
import {
  Component,
  Input,
} from '@angular/core';
import { Item } from 'src/app/core/shared/item.model';
import { MetadataValuesComponent } from 'src/app/item-page/field-components/metadata-values/metadata-values.component';
import { ItemPageFieldComponent } from 'src/app/item-page/simple/field-components/specific-field/item-page-field.component';

interface ProcessedMetadata {
  label: string;
  value: string;
}

@Component({
  selector: 'ds-item-page-local-field',
  templateUrl: '../../../../../../../../app/item-page/simple/field-components/specific-field/item-page-field.component.html',
  // styleUrls: ['./item-page-local.component.scss'],
  standalone: true,
  imports: [
    MetadataValuesComponent,
    AsyncPipe,
  ],
})
/**
 * This component is used for displaying the abstract (dc.description.abstract) of an item
 */
export class ItemPageLocalFieldComponent extends ItemPageFieldComponent {

  /**
   * The item to display metadata for
   */
  @Input() item: Item;

  /**
   * Separator string between multiple values of the metadata fields defined
   */
  @Input() separator: string;

  /**
   * Fields (schema.element.qualifier) used to render their values.
   * In this component, we want to display values for metadata 'dc.description'
   */
  @Input() fields: string[] = [
    'local.description.viz',
    'local.description.raw',
  ];

  /**
   * Label i18n key for the rendered metadata
   */
  @Input() label = 'item.page.local.description';

  /**
   * Use the {@link MarkdownDirective} to render dc.description values
   */
  enableMarkdown = true;

  /**
   * Array to hold the processed metadata for display
   */
  displayDescriptions: ProcessedMetadata[] = [];

}
