import { Component } from '@angular/core';
import { NgIf } from '@angular/common';
import { RouterLink } from '@angular/router';
import { NgbDropdownModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';

/* Example base class; remove if not needed */
import { HeaderComponent as BaseComponent } from 'src/app/header/header.component';

@Component({
  selector: 'ds-pedsnet-header',
  standalone: true,
  templateUrl: './pedsnet-header.component.html',
  styleUrls: ['./pedsnet-header.component.scss'],
  imports: [
    RouterLink,
    NgIf,
    NgbDropdownModule,
    TranslateModule,
  ],
})
export class PEDSnetHeaderComponent extends BaseComponent {
  // Controls whether the mobile menu is collapsed.
  menuCollapsed: boolean = true;

  toggleMenu(): void {
    this.menuCollapsed = !this.menuCollapsed;
  }
}
