import {
  AsyncPipe,
  DatePipe,
  NgIf,
} from '@angular/common';
import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

import { FooterComponent as BaseComponent } from '../../../../app/footer/footer.component';

@Component({
  selector: 'ds-themed-footer',
  styleUrls: ['./footer.component.scss'],
  // styleUrls: ['../../../../app/footer/footer.component.scss'],
  templateUrl: './footer.component.html',
  // templateUrl: '../../../../app/footer/footer.component.html',
  standalone: true,
  imports: [NgIf, RouterLink, AsyncPipe, DatePipe, TranslateModule],
})
export class FooterComponent extends BaseComponent {
  // Enable the PEDSnet footer
  showTopFooter = true;

  // Control visibility of additional sections (set to false if not needed)
  showDisclaimer = true;
  showDSpaceFooter = true; // Keep original DSpace footer links
}
