import {
  AsyncPipe,
  NgClass,
  NgComponentOutlet,
  NgFor,
  NgIf,
} from '@angular/common';
import {
  Component,
  Injector,
  Input,
} from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import copy from 'copy-to-clipboard';
import { AuthorizationDataService } from 'src/app/core/data/feature-authorization/authorization-data.service';
import { Item } from 'src/app/core/shared/item.model';

import { MenuComponent } from '../../menu/menu.component';
import { MenuService } from '../../menu/menu.service';
import { MenuID } from '../../menu/menu-id.model';
import { ThemeService } from '../../theme-support/theme.service';

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
  isCopied = false; // Track whether the permalink was copied
  permalinkType: 'doi' | 'handle' | null = null; // Track the type of permalink

  /**
   * The menu ID of this component is DSO_EDIT
   * @type {MenuID.DSO_EDIT}
   */
  menuID = MenuID.DSO_EDIT;

  copyPermalink() {
    const uriMetadata = this.object.metadata['dc.identifier.uri'];

    // Find the first URI containing 'doi.org'
    let targetUri = uriMetadata?.find(uri => uri.value.includes('doi.org'));
    let isDOI = false;

    // If no DOI found, look for hdl.handle.net
    if (targetUri) {
      isDOI = true;
    } else {
      targetUri = uriMetadata?.find(uri => uri.value.includes('hdl.handle.net'));
    }

    const permalink = targetUri?.value || '';
    copy(permalink);
    this.showCopyMessage = true;
    this.isCopied = true; // show the checkmark icon

    setTimeout(() => {
      this.showCopyMessage = false;
      this.isCopied = false; // revert back to clipboard icon after 3 seconds
    }, 3000);
  }

  /**
   * Get the permalink type for the current item
   */
  getPermalinkType(): 'doi' | 'handle' | null {
    const uriMetadata = this.object?.metadata['dc.identifier.uri'];

    if (!uriMetadata || uriMetadata.length === 0) {
      return null;
    }

    // Check for DOI first (higher priority)
    const hasDOI = uriMetadata.some(uri => uri.value.includes('doi.org'));
    if (hasDOI) {
      return 'doi';
    }

    // Check for Handle
    const hasHandle = uriMetadata.some(uri => uri.value.includes('hdl.handle.net'));
    if (hasHandle) {
      return 'handle';
    }

    return null;
  }

  constructor(protected menuService: MenuService,
              protected injector: Injector,
              public authorizationService: AuthorizationDataService,
              public route: ActivatedRoute,
              protected themeService: ThemeService,
  ) {
    super(menuService, injector, authorizationService, route, themeService);
  }

}
