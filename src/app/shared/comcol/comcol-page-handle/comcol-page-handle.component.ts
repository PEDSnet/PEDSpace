import {
  NgClass,
  NgIf,
} from '@angular/common';
import {
  Component,
  Input,
} from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import copy from 'copy-to-clipboard';

/**
 * This component builds a URL from the value of "handle"
 */

@Component({
  selector: 'ds-base-comcol-page-handle',
  styleUrls: ['./comcol-page-handle.component.scss'],
  templateUrl: './comcol-page-handle.component.html',
  imports: [
    NgIf,
    NgClass,
    TranslateModule,
  ],
  standalone: true,
})
export class ComcolPageHandleComponent {

  // Optional title
  @Input() title: string;

  // The value of "handle"
  @Input() content: string;

  showCopyMessage = false;
  isCopied = false;

  public getHandle(): string {
    return this.content;
  }

  copyToClipboard() {
    const handle = this.getHandle();
    copy(handle);
    this.showCopyMessage = true;
    this.isCopied = true;

    setTimeout(() => {
      this.showCopyMessage = false;
      this.isCopied = false;
    }, 3000);
  }
}
