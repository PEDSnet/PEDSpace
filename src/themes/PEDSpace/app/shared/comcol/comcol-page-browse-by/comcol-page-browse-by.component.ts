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
    // this is where we crudely filter out unwanted metadata fields by their browse-by name from the config file (see local.cfg or dspace.cfg)
    return options.filter(option => !option.id.includes('type') && 
      !option.id.includes('srsc') && 
      !option.id.includes('quality') && 
      !option.id.includes('domain') && 
      !option.id.includes('response') && 
      !option.id.includes('funder') && 
      !option.id.includes('vocab') && 
      !option.id.includes('requirement'));
  }
}

@Component({
  selector: 'ds-themed-comcol-page-browse-by',
  // styleUrls: ['../../../../../../app/shared/comcol/comcol-page-browse-by/comcol-page-browse-by.component.scss'],
  styleUrls: ['./comcol-page-browse-by.component.scss'],
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