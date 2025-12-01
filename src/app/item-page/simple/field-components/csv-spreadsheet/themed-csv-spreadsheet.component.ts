import {
  Component,
  Input,
} from '@angular/core';

import { Item } from '../../../../core/shared/item.model';
import { ThemedComponent } from '../../../../shared/theme-support/themed.component';
import { CsvSpreadsheetComponent } from './csv-spreadsheet.component';

@Component({
  selector: 'ds-item-page-csv-spreadsheet',
  templateUrl: '../../../../shared/theme-support/themed.component.html',
  standalone: true,
  imports: [CsvSpreadsheetComponent],
})
export class ThemedCsvSpreadsheetComponent extends ThemedComponent<CsvSpreadsheetComponent> {

    @Input() item: Item;

    protected inAndOutputNames: (keyof CsvSpreadsheetComponent & keyof this)[] = ['item'];

    protected getComponentName(): string {
      return 'CsvSpreadsheetComponent';
    }

    protected importThemedComponent(themeName: string): Promise<any> {
      return import(`../../../../../themes/${themeName}/app/item-page/simple/field-components/csv-spreadsheet/csv-spreadsheet.component`);
    }

    protected importUnthemedComponent(): Promise<any> {
      return import(`./csv-spreadsheet.component`);
    }

}
