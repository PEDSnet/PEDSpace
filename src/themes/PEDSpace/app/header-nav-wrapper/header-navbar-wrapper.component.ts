import { Component } from '@angular/core';

import { HeaderNavbarWrapperComponent as BaseComponent } from '../../../../app/header-nav-wrapper/header-navbar-wrapper.component';
import { HeaderComponent } from '../header/header.component';

/**
 * This component represents a wrapper for the horizontal navbar and the header
 */
@Component({
  selector: 'ds-themed-header-navbar-wrapper',
  styleUrls: ['./header-navbar-wrapper.component.scss'],
  templateUrl: './header-navbar-wrapper.component.html',
  standalone: true,
  imports: [HeaderComponent],
})
export class HeaderNavbarWrapperComponent extends BaseComponent {
}

