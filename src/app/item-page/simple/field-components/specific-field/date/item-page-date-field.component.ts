import { Component, Input } from '@angular/core';
import { Item } from '../../../../../core/shared/item.model';
import { ItemPageFieldComponent } from '../item-page-field.component';

@Component({
    selector: 'ds-item-page-date-field',
    templateUrl: '../item-page-field.component.html'
})
/**
 * This component is used for displaying date metadata of an item
 */
export class ItemPageDateFieldComponent extends ItemPageFieldComponent {

    /**
     * The item to display metadata for
     */
    @Input() item: Item;

    /**
     * Separator string between multiple values of the metadata fields defined
     * @type {string}
     */
    @Input() separator: string = ', ';

    /**
     * Fields (schema.element.qualifier) used to render their values.
     * By default, it displays values for metadata 'dc.date.issued'
     */
    @Input() fields: string[] = [
        'dc.date.issued'
    ];

    /**
     * Label i18n key for the rendered metadata
     * By default, it uses 'item.page.date'
     */
    @Input() label: string = 'item.page.date';
}
