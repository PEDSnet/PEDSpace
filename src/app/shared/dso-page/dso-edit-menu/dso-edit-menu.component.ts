import {
  AsyncPipe,
  NgComponentOutlet,
  NgFor,
  NgIf,
  NgClass
} from '@angular/common';
import {
  Component,
  Injector,
  Input,
} from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { AuthorizationDataService } from 'src/app/core/data/feature-authorization/authorization-data.service';

import { MenuComponent } from '../../menu/menu.component';
import { MenuService } from '../../menu/menu.service';
import { MenuID } from '../../menu/menu-id.model';
import { ThemeService } from '../../theme-support/theme.service';
import copy from 'copy-to-clipboard';
import { Item } from 'src/app/core/shared/item.model';

/**
 * Component representing the edit menu and other menus on the dspace object pages
 */
@Component({
  selector: 'ds-dso-edit-menu',
  styleUrls: ['./dso-edit-menu.component.scss'],
  templateUrl: './dso-edit-menu.component.html',
  standalone: true,
  imports: [NgFor, NgIf, NgComponentOutlet, AsyncPipe, NgClass],
})
export class DsoEditMenuComponent extends MenuComponent {

  @Input() object: Item;

  showCopyMessage = false;
  isCopied = false; // Add this line to track whether the permalink was copied

  copyPermalink() {
    const permalink = this.object.metadata['dc.identifier.uri'][0].value;
    copy(permalink);
    this.showCopyMessage = true;
    this.isCopied = true; // show the checkmark icon

    setTimeout(() => {
      this.showCopyMessage = false;
      this.isCopied = false; // revert back to clipboard icon after 3 seconds
    }, 3000);
  }

  /**
   * The menu ID of this component is DSO_EDIT
   * @type {MenuID.DSO_EDIT}
   */
  menuID = MenuID.DSO_EDIT;


  constructor(protected menuService: MenuService,
              protected injector: Injector,
              public authorizationService: AuthorizationDataService,
              public route: ActivatedRoute,
              protected themeService: ThemeService,
  ) {
    super(menuService, injector, authorizationService, route, themeService);
  }

}
