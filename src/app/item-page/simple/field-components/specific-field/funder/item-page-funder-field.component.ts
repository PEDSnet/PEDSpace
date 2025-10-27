import {
  AsyncPipe,
  NgFor,
  NgIf,
} from '@angular/common';
import {
  Component,
  Input,
  OnInit,
} from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { BehaviorSubject } from 'rxjs';
import { BrowseDefinitionDataService } from 'src/app/core/browse/browse-definition-data.service';
import { BrowseService } from 'src/app/core/browse/browse.service';
import { Item } from 'src/app/core/shared/item.model';
import { MetadataFieldWrapperComponent } from 'src/app/shared/metadata-field-wrapper/metadata-field-wrapper.component';

/**
 * Component that displays funder information with optional grant details
 * This component renders dc.contributor with browse links and appends grant information
 */
@Component({
  selector: 'ds-item-page-funder-field',
  templateUrl: './item-page-funder-field.component.html',
  styleUrls: ['./item-page-funder-field.component.scss'],
  standalone: true,
  imports: [
    NgIf,
    NgFor,
    AsyncPipe,
    TranslateModule,
    MetadataFieldWrapperComponent,
    RouterLink,
  ],
})
export class ItemPageFunderFieldComponent implements OnInit {
  /**
   * The item to display the funder information for
   */
  @Input() item: Item;

  /**
   * The label to display (optional)
   */
  @Input() label = 'item.preview.dc.contributor';

  /**
   * The funder metadata values from dc.contributor
   */
  funders: any[] = [];

  /**
   * The grant information from local.contributor.grant
   */
  grantInfo: string | null = null;

  /**
   * Whether this includes PCORI-specific disclaimer
   */
  hasPCORIDisclaimer = false;

  /**
   * Browse definition for funders (if available)
   */
  browseDefinition$ = new BehaviorSubject<any>(null);

  constructor(
    private browseDefinitionDataService: BrowseDefinitionDataService,
    private browseService: BrowseService,
  ) {}

  ngOnInit(): void {
    this.loadFunderData();
    this.loadBrowseDefinition();
  }

  /**
   * Load funder and grant data from item metadata
   */
  loadFunderData(): void {
    if (!this.item) {
      return;
    }

    const metadata = this.item.metadata;

    // Extract funders from dc.contributor
    const funderFields = metadata['dc.contributor'] || [];
    this.funders = funderFields.map((field: any) => field.value);

    // Extract grant information from local.contributor.grant
    const grantField = metadata['local.contributor.grant']?.[0];
    this.grantInfo = grantField ? grantField.value : null;

    // Check if any funder is PCORI
    this.hasPCORIDisclaimer = this.funders.some(funder => 
      funder.toLowerCase().includes('patient-centered outcomes research institute') || 
      funder.toLowerCase().includes('pcori')
    );
  }

  /**
   * Load browse definition for dc.contributor
   */
  loadBrowseDefinition(): void {
    // Try to load browse definition for contributor field
    this.browseDefinitionDataService.findByFields(['dc.contributor']).subscribe(
      (browseDefRD) => {
        if (browseDefRD?.payload) {
          this.browseDefinition$.next(browseDefRD.payload);
        }
      }
    );
  }

  /**
   * Get query params for browse link
   */
  getQueryParams(value: string) {
    const browseDefinition = this.browseDefinition$.getValue();
    if (!browseDefinition) {
      return {};
    }
    return { value: value };
  }

  /**
   * Check if we have a browse definition
   */
  hasBrowseDefinition(): boolean {
    return this.browseDefinition$.getValue() !== null;
  }
}
