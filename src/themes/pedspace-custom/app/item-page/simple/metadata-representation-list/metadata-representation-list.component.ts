import { MetadataRepresentationListComponent as BaseComponent } from '../../../../../../app/item-page/simple/metadata-representation-list/metadata-representation-list.component';
import { Component } from '@angular/core';

@Component({
  selector: 'ds-metadata-representation-list',
  templateUrl: './metadata-representation-list.component.html'
  // templateUrl: '../../../../../../app/item-page/simple/metadata-representation-list/metadata-representation-list.component.html'
})

export class MetadataRepresentationListComponent extends BaseComponent {
  showElement: boolean;

  ngOnInit() {
    super.ngOnInit();
    // Check the length of metadata and set showElement accordingly
    const metadata = this.parentItem.findMetadataSortedByPlace(this.metadataFields);
    this.showElement = metadata.length > 1;
  }
}
