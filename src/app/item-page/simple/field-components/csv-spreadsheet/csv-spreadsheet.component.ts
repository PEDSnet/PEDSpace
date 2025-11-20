import {
  isPlatformBrowser,
  CommonModule,
} from '@angular/common';
import {
  Component,
  Inject,
  Input,
  OnInit,
  PLATFORM_ID,
} from '@angular/core';
import {
  TranslateModule,
  TranslateService,
} from '@ngx-translate/core';
import { HotTableModule } from '@handsontable/angular-wrapper';
import { registerAllModules } from 'handsontable/registry';
import type { GridSettings } from 'handsontable/settings';
import { BehaviorSubject } from 'rxjs';
import {
  APP_CONFIG,
  AppConfig,
} from 'src/config/app-config.interface';

import { BitstreamDataService } from '../../../../core/data/bitstream-data.service';
import { PaginatedList } from '../../../../core/data/paginated-list.model';
import { RemoteData } from '../../../../core/data/remote-data';
import { Bitstream } from '../../../../core/shared/bitstream.model';
import { Item } from '../../../../core/shared/item.model';
import { getFirstCompletedRemoteData } from '../../../../core/shared/operators';
import { hasValue } from '../../../../shared/empty.util';
import { ThemedLoadingComponent } from '../../../../shared/loading/themed-loading.component';
import { MetadataFieldWrapperComponent } from '../../../../shared/metadata-field-wrapper/metadata-field-wrapper.component';
import { NotificationsService } from '../../../../shared/notifications/notifications.service';
import { VarDirective } from '../../../../shared/utils/var.directive';
import { HttpClient } from '@angular/common/http';

/**
 * This component renders CSV files from the item's bitstreams
 * as an interactive spreadsheet using Handsontable.
 */
@Component({
  selector: 'ds-base-item-page-csv-spreadsheet',
  templateUrl: './csv-spreadsheet.component.html',
  styleUrls: ['./csv-spreadsheet.component.scss'],
  imports: [
    CommonModule,
    MetadataFieldWrapperComponent,
    ThemedLoadingComponent,
    TranslateModule,
    VarDirective,
    HotTableModule,
  ],
  standalone: true,
})
export class CsvSpreadsheetComponent implements OnInit {

  @Input() item: Item;

  label = 'item.page.csv.spreadsheet';

  csvBitstreams$: BehaviorSubject<Bitstream[]>;

  isLoading: boolean;

  isCollapsed: boolean = true;

  isBrowser: boolean;

  spreadsheetData: any[][] = [];

  totalRows: number = 0;

  gridSettings: GridSettings = {
    rowHeaders: true,
    colHeaders: true,
    height: 400,
    width: '100%',
    autoWrapRow: false,
    autoWrapCol: false,
    licenseKey: 'non-commercial-and-evaluation',
    readOnly: true,
    stretchH: 'none',
    filters: true,
    dropdownMenu: ['filter_by_condition', 'filter_by_value', 'filter_action_bar'],
    columnSorting: true,
    contextMenu: ['copy'],
    manualColumnResize: true,
    manualRowResize: true,
    viewportRowRenderingOffset: 50,
    viewportColumnRenderingOffset: 50,
    fixedRowsTop: 1,
  };

  constructor(
    protected bitstreamDataService: BitstreamDataService,
    protected notificationsService: NotificationsService,
    protected translateService: TranslateService,
    protected httpClient: HttpClient,
    @Inject(APP_CONFIG) protected appConfig: AppConfig,
    @Inject(PLATFORM_ID) private platformId: Object,
  ) {
    this.isBrowser = isPlatformBrowser(this.platformId);
    
    // Only register Handsontable modules in the browser
    if (this.isBrowser) {
      registerAllModules();
    }
  }

  ngOnInit(): void {
    this.csvBitstreams$ = new BehaviorSubject([]);
    this.loadCsvBitstreams();
  }

  /**
   * Load CSV files from the item's bitstreams
   */
  private loadCsvBitstreams(): void {
    this.isLoading = true;
    
    this.bitstreamDataService.findAllByItemAndBundleName(this.item, 'ORIGINAL', {
      currentPage: 1,
      elementsPerPage: 100,
    }).pipe(
      getFirstCompletedRemoteData(),
    ).subscribe((bitstreamsRD: RemoteData<PaginatedList<Bitstream>>) => {
      if (bitstreamsRD.errorMessage) {
        this.notificationsService.error(
          this.translateService.get('csv-spreadsheet.error.header'),
          `${bitstreamsRD.statusCode} ${bitstreamsRD.errorMessage}`
        );
        this.isLoading = false;
      } else if (hasValue(bitstreamsRD.payload)) {
        // Filter for CSV files
        const csvFiles = bitstreamsRD.payload.page.filter(
          (bitstream: Bitstream) => {
            const name = bitstream.name?.toLowerCase() || '';
            return name.endsWith('.csv');
          }
        );
        
        this.csvBitstreams$.next(csvFiles);
        
        // Load the first CSV file if available
        if (csvFiles.length > 0) {
          this.loadCsvData(csvFiles[0]);
        } else {
          this.isLoading = false;
        }
      }
    });
  }

  /**
   * Load and parse CSV data from a bitstream
   */
  private loadCsvData(bitstream: Bitstream): void {
    const downloadUrl = bitstream._links?.content?.href;
    
    if (!downloadUrl) {
      this.isLoading = false;
      return;
    }

    this.httpClient.get(downloadUrl, { responseType: 'text' }).subscribe({
      next: (csvText: string) => {
        this.spreadsheetData = this.parseCsv(csvText);
        this.isLoading = false;
      },
      error: (error) => {
        this.notificationsService.error(
          this.translateService.get('csv-spreadsheet.error.load'),
          error.message
        );
        this.isLoading = false;
      }
    });
  }

  /**
   * Toggle collapse/expand state
   */
  toggleCollapse(): void {
    this.isCollapsed = !this.isCollapsed;
  }

  /**
   * Parse CSV text into a 2D array
   */
  private parseCsv(csvText: string): any[][] {
    const lines = csvText.split('\n');
    const result: any[][] = [];
    
    for (const line of lines) {
      if (line.trim()) {
        // Basic CSV parsing - handles quoted fields
        const row = this.parseCsvLine(line);
        result.push(row);
      }
    }
    
    this.totalRows = result.length;
    return result;
  }

  /**
   * Parse a single CSV line, handling quoted fields
   */
  private parseCsvLine(line: string): string[] {
    const result: string[] = [];
    let current = '';
    let inQuotes = false;
    
    for (let i = 0; i < line.length; i++) {
      const char = line[i];
      const nextChar = line[i + 1];
      
      if (char === '"') {
        if (inQuotes && nextChar === '"') {
          current += '"';
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char === ',' && !inQuotes) {
        result.push(current);
        current = '';
      } else {
        current += char;
      }
    }
    
    result.push(current);
    return result;
  }
}
