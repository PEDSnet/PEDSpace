import {
  NgClass,
  NgFor,
} from '@angular/common';
import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';

import { StartsWithAlphabetComponent as BaseComponent } from '../../../../../../app/shared/starts-with/alphabet/starts-with-alphabet.component';

@Component({
  selector: 'ds-starts-with-alphabet',
  styleUrls: ['../../../../../../app/shared/starts-with/alphabet/starts-with-alphabet.component.scss'],
  templateUrl: '../../../../../../app/shared/starts-with/alphabet/starts-with-alphabet.component.html',
  standalone: true,
  imports: [NgFor, NgClass, TranslateModule],
})
export class StartsWithAlphabetComponent extends BaseComponent {
}