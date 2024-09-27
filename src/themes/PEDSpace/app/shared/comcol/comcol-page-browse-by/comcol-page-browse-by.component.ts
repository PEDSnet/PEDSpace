/* eslint-disable max-classes-per-file */
import {
  AsyncPipe,
  NgForOf,
  NgIf,
} from '@angular/common';
import {
  Component,
  Pipe,
  PipeTransform,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  RouterLink,
  RouterLinkActive,
} from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import { ComcolPageBrowseByComponent as BaseComponent } from '../../../../../../app/shared/comcol/comcol-page-browse-by/comcol-page-browse-by.component';

@Pipe({
  name: 'filterType',
  standalone: true,
})
export class FilterTypePipe implements PipeTransform {
  transform(options: any[]): any[] {
    // this is where we crudely filter out unwanted metadata fields by dc schema name ie. 'dc.type' or 'browse.comcol.by.srsc'
    return options.filter(option => !option.id.includes('type') && !option.id.includes('srsc') && !option.id.includes('quality'));
  }
}

@Component({
  selector: 'ds-themed-comcol-page-browse-by',
  styleUrls: ['../../../../../../app/shared/comcol/comcol-page-browse-by/comcol-page-browse-by.component.scss'],
  templateUrl: './comcol-page-browse-by.component.html',
  standalone: true,
  imports: [
    FormsModule,
    NgForOf,
    RouterLink,
    RouterLinkActive,
    TranslateModule,
    AsyncPipe,
    NgIf,
    FilterTypePipe,
  ],
})
export class ComcolPageBrowseByComponent extends BaseComponent {
}