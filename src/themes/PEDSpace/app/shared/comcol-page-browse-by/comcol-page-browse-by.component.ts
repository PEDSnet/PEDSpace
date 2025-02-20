import { Component } from '@angular/core';

import { ComcolPageBrowseByComponent as BaseComponent } from '../../../../../app/shared/comcol/comcol-page-browse-by/comcol-page-browse-by.component';

/**
 * A component to display the "Browse By" section of a Community or Collection page
 * It expects the ID of the Community or Collection as input to be passed on as a scope
 */
@Component({
  selector: 'ds-base-comcol-page-browse-by',
  // styleUrls: ['./comcol-page-browse-by.component.scss'],
  styleUrls: ['../../../../../app/shared/comcol/comcol-page-browse-by/comcol-page-browse-by.component.scss'],
  // templateUrl: './comcol-page-browse-by.component.html'
  templateUrl: '../../../../../app/shared/comcol/comcol-page-browse-by/comcol-page-browse-by.component.html',
  standalone: true,
})
export class ComcolPageBrowseByComponent extends BaseComponent {}
