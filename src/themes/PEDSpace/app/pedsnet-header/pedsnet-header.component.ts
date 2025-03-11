import { Component } from '@angular/core';
import { NgIf, AsyncPipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { NgbDropdownModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';

/* Your custom DS components */
import { ThemedLangSwitchComponent } from 'src/app/shared/lang-switch/themed-lang-switch.component';
import { ContextHelpToggleComponent } from 'src/app/header/context-help-toggle/context-help-toggle.component';
import { ThemedSearchNavbarComponent } from 'src/app/search-navbar/themed-search-navbar.component';
import { ThemedAuthNavMenuComponent } from 'src/app/shared/auth-nav-menu/themed-auth-nav-menu.component';
import { ImpersonateNavbarComponent } from 'src/app/shared/impersonate-navbar/impersonate-navbar.component';
import { ExpandableNavbarSectionComponent } from 'src/app/navbar/expandable-navbar-section/expandable-navbar-section.component';

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
    AsyncPipe,
    NgbDropdownModule,
    TranslateModule,
    ExpandableNavbarSectionComponent,
    ThemedLangSwitchComponent,
    ThemedSearchNavbarComponent,
    ContextHelpToggleComponent,
    ThemedAuthNavMenuComponent,
    ImpersonateNavbarComponent
  ],
})
export class PEDSnetHeaderComponent extends BaseComponent {
  // Add any custom logic if needed.
}
