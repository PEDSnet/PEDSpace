import {
  AsyncPipe,
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
 * Component that displays funder information with optional grant details
 */
@Component({
  selector: 'ds-item-page-funder-field',
  templateUrl: './item-page-funder-field.component.html',
  styleUrls: ['./item-page-funder-field.component.scss'],
  standalone: true,
  imports: [
    NgIf,
    AsyncPipe,
    TranslateModule,
    MetadataFieldWrapperComponent,
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
   * The generated funder text
   */
  funderText: string;

  /**
   * Whether this includes PCORI-specific disclaimer
   */
  hasPCORIDisclaimer = false;

  ngOnInit(): void {
    this.generateFunderText();
  }

  /**
   * Generate funder text from item metadata
   */
  generateFunderText(): void {
    if (!this.item) {
      return;
    }

    const metadata = this.item.metadata;

    // Extract funder from dc.contributor
    const funderField = metadata['dc.contributor']?.[0];
    if (!funderField) {
      return;
    }

    const funderName = funderField.value;

    // Extract grant information from local.contributor.grant
    const grantField = metadata['local.contributor.grant']?.[0];
    const grantInfo = grantField ? grantField.value : null;

    // Build the funder statement
    let statement = `This research was made possible through the generous support of the ${funderName}`;

    // Check if this is a PCORI-funded project
    const isPCORI = funderName.toLowerCase().includes('patient-centered outcomes research institute') || 
                    funderName.toLowerCase().includes('pcori');

    if (grantInfo) {
      statement += ` ${grantInfo}`;
    }

    statement += '.';

    // Add PCORI disclaimer if applicable
    if (isPCORI) {
      this.hasPCORIDisclaimer = true;
      statement += ' The statements presented in this work are solely the responsibility of the author(s) and do not necessarily represent the views of PCORI, its Board of Governors, or its Methodology Committee.';
    }

    this.funderText = statement;
  }
}
