import { NgIf, NgClass } from '@angular/common';
import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { TypeBadgeComponent as BaseComponent } from 'src/app/shared/object-collection/shared/badges/type-badge/type-badge.component';

@Component({
  selector: 'ds-verification-badge',
  styleUrls: ['./verification-badge.component.scss'],
  templateUrl: './verification-badge.component.html',
  // templateUrl: '../../../../../../../../app/shared/object-collection/shared/badges/type-badge/type-badge.component.html',
  standalone: true,
  imports: [NgIf, NgClass, TranslateModule],
})
export class VerificationBadgeComponent extends BaseComponent {
  _verificationStatus: string;

  ngOnInit() {
    this.setVerificationStatus();
  }

  private setVerificationStatus() {
    this._verificationStatus = `${this.object.firstMetadataValue('local.quality.status').toLowerCase().split(" ").join("")}.listelement.badge`;
    // this._typeMessage = `${renderType.name.toLowerCase()}.listelement.badge`;

  }

  get verificationStatus(): string {
    return this._verificationStatus;
  }

  
}
